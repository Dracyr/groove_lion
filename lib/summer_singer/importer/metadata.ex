defmodule SummerSinger.Importer.Metadata do
  alias SummerSinger.{Repo, Track, Album, Artist, CoverArt}
  alias SummerSinger.Importer.MusicTagger
  import Ecto.Query

  def perform(opts \\ [include_all: false]) do
    artists =
      from(a in Artist, select: {a.name, a})
      |> Repo.all()
      |> Map.new

    albums =
      from(a in Album, select: {{a.title, a.artist_id}, a}, preload: [:cover_art])
      |> Repo.all()
      |> Map.new

    tracks =
      if opts[:include_all],
        do: from(t in Track),
        else: from(t in Track, where: not t.imported)
      |> Repo.all()

    total_tracks = length(tracks)
    ProgressBar.render(0, total_tracks)

    tracks
    |> Stream.transform({artists, albums}, &to_changesets/2)
    |> Stream.chunk(30, 30, [])
    |> Stream.each(fn chunk ->
      Enum.reduce(chunk, Ecto.Multi.new, fn(cset, multi) ->
        Ecto.Multi.update(multi, Ecto.UUID.generate, cset)
      end)
      |> Repo.transaction
    end)
    |> Stream.with_index
    |> Stream.each(fn {chunk, index} ->
      ProgressBar.render(length(chunk) * index, total_tracks)
    end)
    |> Stream.run
  end

  def to_changesets(track, {artists, albums}) do
    result =
      with {:ok, audio_properties, tags} <-
            MusicTagger.fetch_tags(track.path),
          {:ok, cover_art} <-
            MusicTagger.fetch_cover(track.path),
          {:ok, {artists, albums}, artist, album, cover_art} <-
            get_resources({artists, albums}, tags["ARTIST"], tags["ALBUMARTIST"], tags["ALBUM"], cover_art),
          {:ok, updated_track} <-
            update_track(track, audio_properties, tags, artist, album, cover_art),
      do: {:ok, updated_track, {artists, albums}}

    case result do
      {:ok, updated_track, {artists, albums}} ->
        {[updated_track], {artists, albums}}
      _ ->
        {[], {artists, albums}}
    end
  end

  def get_resources({artists, albums}, artist_name, album_artist_name, album_title, cover_art) do
    multi =
      Ecto.Multi.new
      |> Ecto.Multi.run(:artist, &fetch_artist(&1, artists, artist_name))
      |> Ecto.Multi.run(:album_artist, &fetch_album_artist(&1, artists, album_artist_name))
      |> Ecto.Multi.run(:album, &fetch_album(&1, albums, album_title))
      |> Ecto.Multi.run(:cover_art, &fetch_cover_art(&1, cover_art))
      |> Ecto.Multi.run(:cover_art_image, &update_cover_image(&1, cover_art))
      |> Ecto.Multi.run(:update_album_cover, &update_album_cover/1)

    case Repo.transaction(multi) do
      {:ok, res} ->
        %{
          artist: artist,
          album_artist: album_artist,
          album: album,
          cover_art: cover_art
        } = res

        artists = if artist,
          do: Map.put_new(artists, artist.name, artist),
          else: artists
        artists = if album_artist,
          do: Map.put_new(artists, album_artist.name, album_artist),
          else: artists
        albums = if album,
          do: Map.put_new(albums, {album.title, album.artist_id}, album),
          else: albums

        {:ok, {artists, albums}, artist, album, cover_art}
      _ ->
        :error
    end
  end

  def fetch_artist(_, _, nil), do: {:ok, nil}
  def fetch_artist(%{}, artists, artist_name) do
    case Map.fetch(artists, artist_name) do
      {:ok, artist} -> {:ok, artist}
      :error ->
        Artist.changeset(%Artist{}, %{name: artist_name})
        |> Repo.insert
    end
  end

  def fetch_album_artist(_, _, nil), do: {:ok, nil}
  def fetch_album_artist(%{artist: artist}, artists, artist_name) do
    album_artist =
      if artist && artist.name == artist_name,
        do: {:ok, artist},
        else: Map.fetch(artists, artist_name)

    case album_artist do
      {:ok, artist} -> {:ok, artist}
      :error ->
        Artist.changeset(%Artist{}, %{name: artist_name})
        |> Repo.insert
    end
  end

  def fetch_album(_, _, nil, _), do: {:ok, nil}
  def fetch_album(%{artist: artist, album_artist: album_artist}, albums, album_title) do
    artist_id = (album_artist || artist).id

    case Map.fetch(albums, {album_title, artist_id}) do
      {:ok, album} -> {:ok, album}
      :error ->
        Album.changeset(%Album{}, %{
          title: album_title,
          artist_id: artist_id
        })
        |> Repo.insert
    end
  end

  def fetch_cover_art(_, nil), do: {:ok, nil}
  def fetch_cover_art(%{album: album}, cover_art) do
    album = Repo.preload(album, :cover_art)
    case album.cover_art do
      nil ->
        CoverArt.changeset(%CoverArt{}, %{
          mime_type: cover_art.mime_type,
          description: cover_art.description,
          picture_type: cover_art.picture_type,
        })
        |> Repo.insert
      cover_art -> {:ok, cover_art}
    end
  end

  def update_cover_image(_, nil), do: {:ok, nil}
  def update_cover_image(%{cover_art: nil}, _), do: {:ok, nil}
  def update_cover_image(%{cover_art: cover_art}, cover) do
    ext = case cover.mime_type do
      "image/jpeg" -> "jpg"
      "image/jpg" -> "jpg" # Hey, this isn't a real mimetype
      "image/png" -> "png"
      _ -> nil
    end

    if !is_nil(ext) do
      CoverArt.changeset(cover_art, %{
        cover_art: %{filename: "cover.#{ext}", binary: cover.image}
      })
      |> Repo.update
    else
      {:ok, nil}
    end
  end

  def update_album_cover(%{cover_art: nil}), do: {:ok, nil}
  def update_album_cover(%{album: nil}), do: {:ok, nil}
  def update_album_cover(%{album: album, cover_art: cover_art}) do
    if album.cover_art_id do
      {:ok, album}
    else
      album
      |> Repo.preload(:cover_art)
      |> Album.changeset(%{cover_art_id: cover_art.id})
      |> Repo.update
    end
  end

  defp convert_rating(nil), do: 0
  defp convert_rating(rating) when is_binary(rating),
    do: String.to_integer(rating)
  defp convert_rating(rating),
    do: rating

  def update_track(track, audio_properties, tags, artist, album, cover_art) do
    {
      :ok,
      Track.changeset(track, %{
        title: tags["TITLE"],
        artist_id: artist && artist.id,
        album_id: album && album.id,
        cover_art_id: cover_art && cover_art.id,
        duration: audio_properties["duration"] / 1,
        rating: convert_rating(tags["RATING"]),
        metadata: %{
          audio_properties: audio_properties,
          tags: tags,
        },
        imported: true
      })
    }
  end
end
