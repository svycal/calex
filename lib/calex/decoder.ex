defmodule Calex.Decoder do
  @moduledoc false

  # https://rubular.com/r/sXPKG84KfgtfMV
  @local_datetime_pattern ~r/^\d{8}T\d{6}$/

  # https://rubular.com/r/eyHVyPdFI5KLF7
  @utc_datetime_pattern ~r/^\d{8}T\d{6}Z$/
  @date_pattern ~r/^\d{8}$/

  def decode!(data) do
    data
    |> decode_lines
    |> decode_blocks
  end

  defp decode_lines(bin) do
    bin
    |> String.splitter(["\r\n", "\n"])
    |> Enum.flat_map_reduce(nil, fn
      " " <> rest, acc ->
        {[], acc <> rest}

      line, prevline ->
        {(prevline && [String.replace(prevline, "\\n", "\n")]) || [], line}
    end)
    |> elem(0)
  end

  defp decode_blocks([]), do: []

  # decode each block as a list
  defp decode_blocks(["BEGIN:" <> binkey | rest]) do
    {props, [_ | lines_rest]} = Enum.split_while(rest, &(!match?("END:" <> ^binkey, &1)))
    key = decode_key(binkey)

    # accumulate block of same keys
    case decode_blocks(lines_rest) do
      [{^key, elems} | props_rest] -> [{key, [decode_blocks(props) | elems]} | props_rest]
      props_rest -> [{key, [decode_blocks(props)]} | props_rest]
    end
  end

  # recursive decoding if no BEGIN/END block
  defp decode_blocks([prop | rest]), do: [decode_prop(prop) | decode_blocks(rest)]

  # decode key,params and value for each prop
  defp decode_prop(prop) do
    [keyprops, val] = String.split(prop, ":", parts: 2)

    case String.split(keyprops, ";") do
      [key] ->
        {decode_key(key), {decode_value(val, []), []}}

      [key | props] ->
        props =
          props
          |> Enum.map(fn prop ->
            [k, v] =
              case String.split(prop, "=") do
                [k1, v1] ->
                  [k1, v1]

                [k1 | tl] ->
                  # This case handles malformed X-APPLE-STRUCTURED-LOCATION
                  # properties that fail to quote-escape `=` characters.
                  [k1, Enum.join(tl, "=")]
              end

            {decode_key(k), v}
          end)

        {decode_key(key), {decode_value(val, props), props}}
    end
  end

  defp decode_value(val, props) do
    time_zone = Keyword.get(props, :tzid)

    cond do
      String.match?(val, @local_datetime_pattern) && time_zone ->
        decode_local_datetime(val, time_zone)

      String.match?(val, @utc_datetime_pattern) ->
        decode_utc_datetime(val)

      String.match?(val, @date_pattern) && Keyword.get(props, :value) == "DATE" ->
        decode_date(val)

      true ->
        val
    end
  end

  defp decode_local_datetime(val, time_zone) do
    val
    |> Timex.parse!("{YYYY}{0M}{0D}T{h24}{m}{s}")
    |> DateTime.from_naive!(time_zone)
  end

  defp decode_utc_datetime(val) do
    val
    |> Timex.parse!("{YYYY}{0M}{0D}T{h24}{m}{s}Z")
    |> DateTime.from_naive!("Etc/UTC")
  end

  defp decode_date(val) do
    val
    |> Timex.parse!("{YYYY}{0M}{0D}")
    |> NaiveDateTime.to_date()
  end

  defp decode_key(bin) do
    bin
    |> String.replace("-", "_")
    |> String.downcase()
    |> String.to_atom()
  end
end
