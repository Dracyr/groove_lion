defmodule ID3v2Parser do
  alias ID3v2Parser.TagFrame

  def parse_binary(binary) do
    case parse_header(binary) do
      {:ok, header_info} ->
        parse_binary(binary, header_info)
      _ ->
        {:error, :no_tag}
    end
  end

  defp parse_binary(binary, header_info) do
    length = header_info[:length]
    <<
      _header     :: binary-size(10),
      tag_frames  :: binary-size(length),
      _audio_data :: binary >> = binary

    try do
      tag_frames = metadata_frames(tag_frames, %{})

      {:ok,
        %{
          title: tag_frames["TIT2"],
          artist: tag_frames["TPE1"],
          album: tag_frames["TALB"],
          year: tag_frames["TYER"],
          rating: tag_frames["POPM"],
          comment: tag_frames["COMM"],
          album_art:  tag_frames["APIC"],
          tag_frames: tag_frames,
        }
      }
    rescue
      e in ID3v2Parser.TagFrameError ->
        {:error, e.message}
    end
  end

  def parse_header(<<
      "ID3",
      major_version  :: integer-size(8),
      minor_version  :: integer-size(8),
      _unsync        :: bits-size(1), # Unsynchronisation scheme not handled
      _extended      :: bits-size(1), # Extended header not handled yet
      _experimental  :: bits-size(1),
      _flags         :: bits-size(5),
      safe_length    :: bytes-size(4),
      _data          :: binary >>) do

    {:ok, %{
      tag_version: "ID3v2." <> Integer.to_string(major_version) <> "." <> Integer.to_string(minor_version),
      length: unsync_int(safe_length)
    }}
  end
  def parse_header(_), do: {:no_tag, :id3v2}

  defp metadata_frames(<<
      id     :: binary-size(4),
      length :: integer-size(32),
      _flags :: bits-size(16),
      frame  :: binary-size(length),
      binary :: binary >>, metadata) when id != << 0,0,0,0 >> and byte_size(id) == 4 do

    tag_frame = TagFrame.tag_frame(id, frame)
    IO.inspect(id)
    IO.inspect(tag_frame)
    metadata = Map.merge(metadata, tag_frame, fn _k, v1, v2 ->
      if is_map(v1) && is_map(v2) do
        Map.merge(v1, v2)
      else
        List.wrap(v1) ++ List.wrap(v2)
      end
    end)
    metadata_frames(binary, metadata)
  end
  defp metadata_frames(_binary, metadata), do: metadata

  defp unsync_int(<<
      0 :: size(1), byte_1 :: size(7),
      0 :: size(1), byte_2 :: size(7),
      0 :: size(1), byte_3 :: size(7),
      0 :: size(1), byte_4 :: size(7) >>) do

    << unsynced_int :: integer-size(28) >> = <<
      byte_1 :: size(7),
      byte_2 :: size(7),
      byte_3 :: size(7),
      byte_4 :: size(7) >>

    unsynced_int
  end
end
