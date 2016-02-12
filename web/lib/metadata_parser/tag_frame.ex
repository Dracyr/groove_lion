defmodule ID3v2Parser.TagFrame do

  def tag_frame(<< 0, 0, 0, 0 >>, _), do: %{}

  def tag_frame("TXXX", <<
      encoding :: bytes-size(1),
      data      :: binary >>) when encoding == 0x00 or encoding == 0x01 do

    {desc, content} = split_at_null(data)
    Map.put(%{}, desc, to_utf8(encoding, content))
  end
  def tag_frame("TXXX", _data), do: %{}

  def tag_frame("WXXX", <<
      encoding :: bytes-size(1),
      data      :: binary >>) when encoding == 0x00 or encoding == 0x01 do

    {desc, content} = split_at_null(data)
    Map.put(%{}, desc, content)
  end
  def tag_frame("WXXX", _data), do: %{}

  def tag_frame("TCON", <<
      encoding :: bytes-size(1),
      data     :: binary >>) when encoding == 0x00 or encoding == 0x01 do

    genres = Enum.chunk_by(to_char_list(data), &(&1 == 0))
    |> Enum.reject(&(&1 == [0]))

    Map.put(%{}, "TCON", genres)
  end
  def tag_frame("TCON", _data), do: %{}

  def tag_frame("POPM", data) do
    { _user, << rating :: integer-size(8), _counter :: binary >>} = split_at_null(data)
    Map.put(%{}, "POPM", rating)
  end

  def tag_frame("COMM", <<
    encoding :: bytes-size(1),
    _language :: size(24),
    data      :: binary >>) when encoding == 0x00 or encoding == 0x01 do

    {desc, content} = split_at_null(data)
    %{desc: to_utf8(encoding, desc), text: to_utf8(encoding, content)}
  end
  def tag_frame("COMM", _data), do: %{}

  @picture_type %{
    00 => "Other",
    01 => "32x32 pixels 'file icon' (PNG only)",
    02 => "Other file icon",
    03 => "Cover (front)",
    04 => "Cover (back)",
    05 => "Leaflet page",
    06 => "Media (e.g. lable side of CD)",
    07 => "Lead artist/lead performer/soloist",
    08 => "Artist/performer",
    09 => "Conductor",
    10 => "Band/Orchestra",
    11 => "Composer",
    12 => "Lyricist/text writer",
    13 => "Recording Location",
    14 => "During recording",
    15 => "During performance",
    16 => "Movie/video screen capture",
    17 => "A bright coloured fish",
    18 => "Illustration",
    19 => "Band/artist logotype",
    20 => "Publisher/Studio logotype"
  }

  def tag_frame("APIC", <<
      encoding :: bytes-size(1),
      data :: binary >>) when encoding == 0x00 or encoding == 0x01 do

    { mime_type, << picture_type :: integer-size(8), desc_data :: binary >> } = split_at_null(data)
    { description, picture_data } = split_at_null(desc_data)

    apic = %{type: @picture_type[picture_type], mime: mime_type, desc: description, file: picture_data}
    Map.put(%{}, "APIC", [apic])
  end
  def tag_frame("APIC", _data), do: %{}

  def tag_frame(id, data) do
    cond do
      Regex.match?(~r/[WT].../, id) ->
        Map.put(%{}, id, to_utf8(data))
      true ->
        Map.put(%{}, id, data)
    end
  end

  defp split_at_null(binary) do
    {index , 1} = :binary.match binary, << 0 >>
    << head :: bytes-size(index), 0x00, tail :: binary >> = binary
    { head, tail }
  end

  defp to_utf8(<< encoding :: bytes-size(1), string :: bytes >>), do: to_utf8(encoding, string)
  defp to_utf8(encoding, string) do
    case encoding do
      <<0x00>> -> # ISO-8859-1
        Codepagex.to_string!(string, :iso_8859_1)
      <<0x01>> -> # UCS-2 (UTF-16 with BOM)
        :unicode.characters_to_binary(string, elem(:unicode.bom_to_encoding(string), 0))
      <<0x02>> -> #UTF-16BE encoded Unicode without BOM
        :unicode.characters_to_binary(string, {:utf16, :big})
      <<0x03>> -> # Good old UTF-8
        string
      _ -> # No valid encoding, why are you doing this
        encoding <> string
    end
  end
end
