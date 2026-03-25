defmodule Calex.Decoder do
  @moduledoc false

  alias Calex.PropertyName
  alias Calex.{DecodeError, InvalidTimeZoneError}

  # https://rubular.com/r/sXPKG84KfgtfMV
  @utc_datetime_pattern ~r/^\d{8}T\d{6}Z$/
  @local_datetime_pattern ~r/^\d{8}T\d{6}$/
  @date_pattern ~r/^\d{8}$/

  # Should probably make this more robust
  @duration_pattern ~r/^P.*$/

  @gmt_offset_pattern ~r/^GMT(\+|\-)(\d{2})(\d{2})$/

  def decode!(data) do
    data
    |> decode_lines()
    |> decode_blocks()
  end

  defp decode_lines(bin) do
    bin
    |> String.splitter(["\r\n", "\n"])
    |> Enum.flat_map_reduce(nil, fn
      " " <> rest, acc ->
        {[], acc <> rest}

      line, prevline ->
        {(prevline && [prevline]) || [], line}
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
    case split_content_line(prop) do
      ["", _prop_val] ->
        raise DecodeError, message: "property key missing or blank line"

      [prop_key, prop_val] ->
        with prop_key <- PropertyName.parse!(prop_key) do
          if String.upcase(prop_key) == "DURATION" do
            {:duration, {decode_duration(prop_val), []}}
          else
            {decode_key(prop_key), {decode_value(prop_val, []), []}}
          end
        end

      [prop_key | params_and_prop_val] ->
        {raw_params, [prop_val]} = Enum.split(params_and_prop_val, -1)

        params =
          raw_params
          |> Enum.map(fn raw_param ->
            [k, v] = String.split(raw_param, "=", parts: 2)

            {decode_key(k), v}
          end)

        {decode_key(prop_key), {decode_value(prop_val, params), params}}
    end
  end

  defp split_content_line(line),
    do: split_content_line(line, "", [], false)

  # Following parses on a byte-by-byte basis.  This works because multi-byte
  # UTF-8 won't contain these characters (ASCII starts with a 0 bit while all
  # other UTF-8 bytes start with a 1 bit)
  defp split_content_line("", char_acc, list_acc, _in_quotes),
    do: ["" | [char_acc | list_acc]] |> Enum.reverse()

  defp split_content_line(<<"\"", rest::binary>>, char_acc, list_acc, in_quotes),
    do: split_content_line(rest, char_acc, list_acc, not in_quotes)

  defp split_content_line(<<":", rest::binary>>, char_acc, list_acc, false = _in_quotes),
    do: [rest | [char_acc | list_acc]] |> Enum.reverse()

  defp split_content_line(<<";", rest::binary>>, char_acc, list_acc, false = in_quotes),
    do: split_content_line(rest, "", [char_acc | list_acc], in_quotes)

  defp split_content_line(<<char, rest::binary>>, char_acc, list_acc, in_quotes),
    do: split_content_line(rest, char_acc <> <<char>>, list_acc, in_quotes)

  defp decode_value(val, props) do
    time_zone = Keyword.get(props, :tzid)

    cond do
      String.match?(val, @local_datetime_pattern) ->
        decode_local_datetime(val, time_zone)

      String.match?(val, @utc_datetime_pattern) ->
        decode_utc_datetime(val)

      String.match?(val, @date_pattern) && Keyword.get(props, :value) == "DATE" ->
        decode_date(val)

      String.match?(val, @duration_pattern) && Keyword.get(props, :value) == "DURATION" ->
        decode_duration(val)

      true ->
        unescape_prop_value(val)
    end
  end

  defp unescape_prop_value(val) do
    val
    |> String.replace(~r/\\(\\|;|,|N|n)/, fn
      "\\\\" -> "\\"
      "\\;" -> ";"
      "\\," -> ","
      "\\N" -> "\n"
      "\\n" -> "\n"
    end)
  end

  defp decode_local_datetime(val, time_zone) do
    naive_datetime = parse_basic_naive_datetime!(val)

    if time_zone do
      case Regex.run(@gmt_offset_pattern, time_zone) do
        [_, "-", hour, min] ->
          naive_datetime
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.add(String.to_integer(hour), :hour)
          |> DateTime.add(String.to_integer(min), :minute)
          |> DateTime.truncate(:second)

        [_, "+", hour, min] ->
          naive_datetime
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.add(-String.to_integer(hour), :hour)
          |> DateTime.add(-String.to_integer(min), :minute)
          |> DateTime.truncate(:second)

        _ ->
          naive_datetime
          |> from_naive_datetime!(time_zone)
          |> DateTime.truncate(:second)
      end
    else
      naive_datetime
    end
  end

  # Casts a naive date time to a zoned date time.
  #
  # When ambiguous, pick the earlier occurrence.
  #
  #   Rationale: Many ecosystems default to the earlier instant (e.g., Python’s default
  #   before fold=1, java.time’s resolver), and it avoids “unexpectedly
  #   jumping an hour later.” For calendars, users typically think “the time I
  #   typed” should map to the first moment that matches it.
  #
  # When a gap is encountered, pick the later occurrence.
  #
  #   Rationale: The wall time doesn’t exist; advancing to the next valid time
  #   preserves “same clock face time as closely as possible going forward,”
  #   which is what users expect when a 02:30 that doesn’t exist gets
  #   scheduled.
  #
  defp from_naive_datetime!(naive_datetime, time_zone) do
    case DateTime.from_naive(naive_datetime, time_zone) do
      {:ok, datetime} -> datetime
      {:ambiguous, first, _second} -> first
      {:gap, _first, second} -> second
      {:error, term} -> raise InvalidTimeZoneError, message: "failed with #{term} error"
    end
  end

  defp decode_utc_datetime(val) do
    val
    |> String.trim_trailing("Z")
    |> parse_basic_naive_datetime!()
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.truncate(:second)
  end

  defp decode_date(val) do
    parse_basic_date!(val)
  end

  defp decode_key(key) do
    key
    |> PropertyName.parse!()
    |> String.replace("-", "_")
    |> String.downcase()
    |> String.slice(0..254)
    |> String.to_atom()
  end

  defp decode_duration(val) do
    case Duration.from_iso8601(val) do
      {:ok, duration} -> duration
      _ -> val
    end
  end

  defp parse_basic_date!(<<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>) do
    Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))
  end

  defp parse_basic_naive_datetime!(
         <<year::binary-size(4), month::binary-size(2), day::binary-size(2), "T",
           hour::binary-size(2), minute::binary-size(2), second::binary-size(2)>>
       ) do
    date = Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))

    time =
      Time.new!(String.to_integer(hour), String.to_integer(minute), String.to_integer(second))

    NaiveDateTime.new!(date, time)
  end
end
