defmodule Calex.Decoder do
  @moduledoc false

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
        {decode_key(key), val}

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

        {decode_key(key), [{:value, val} | props]}
    end
  end

  defp decode_key(bin) do
    bin
    |> String.replace("-", "_")
    |> String.downcase()
    |> String.to_atom()
  end
end
