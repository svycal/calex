defmodule Calex.Encoder do
  @moduledoc false

  def encode!(props) do
    encode_value(props) <> "\r\n"
  end

  # encode multiple kwlist with begin/end
  defp encode_value({k, [[{_k, _v} | _] | _] = vals}) do
    vals
    |> Enum.map_join(
      "\r\n",
      &"BEGIN:#{encode_key(k)}\r\n#{encode_value(&1)}\r\nEND:#{encode_key(k)}"
    )
  end

  # encode kwlist with limited length lines
  defp encode_value([{_k, _v} | _] = props) do
    props |> Enum.map_join("\r\n", &(&1 |> encode_value() |> encode_line()))
  end

  # encode date values
  defp encode_value({k, {%Date{} = date, props}}) do
    encoded_date = Calendar.strftime(date, "%Y%m%d")
    props = Keyword.put(props, :value, "DATE")
    encode_value({k, {encoded_date, props}})
  end

  # encode UTC datetime values
  defp encode_value({k, {%DateTime{time_zone: "Etc/UTC"} = datetime, props}}) do
    encoded_datetime =
      datetime
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%Y%m%dT%H%M%SZ")

    # TZID property should not be set when datetime is in UTC
    props = Keyword.delete(props, :tzid)

    encode_value({k, {encoded_datetime, props}})
  end

  # encode non-UTC datetime values
  defp encode_value({k, {%DateTime{time_zone: time_zone} = datetime, props}}) do
    encoded_datetime =
      datetime
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%Y%m%dT%H%M%S")

    props = Keyword.put(props, :tzid, time_zone)
    encode_value({k, {encoded_datetime, props}})
  end

  # encode naive datetime values
  defp encode_value({k, {%NaiveDateTime{} = datetime, props}}) do
    encoded_datetime =
      datetime
      |> NaiveDateTime.truncate(:second)
      |> Calendar.strftime("%Y%m%dT%H%M%S")

    encode_value({k, {encoded_datetime, props}})
  end

  # encode value with properties
  defp encode_value({k, {v, [{_k, _v} | _] = props}}) do
    encoded_props =
      props
      |> Enum.map_join(";", fn {pk, pv} -> "#{encode_key(pk)}=#{encode_param_value(pv)}" end)

    "#{encode_key(k)};#{encoded_props}:#{encode_value(v)}"
  end

  # encode value with empty props
  defp encode_value({k, {v, _}}), do: "#{encode_key(k)}:#{encode_value(v)}"

  defp encode_value(atom) when is_atom(atom),
    do: atom |> to_string() |> String.upcase() |> escape_property_value()

  defp encode_value(%Duration{} = duration),
    do: duration |> Duration.to_iso8601() |> escape_property_value()

  defp encode_value(text) when is_binary(text),
    do: text |> escape_property_value()

  defp encode_value(other), do: other |> to_string() |> escape_property_value()

  defp escape_property_value(value) do
    value
    |> String.replace(~r/(\\|;|,|\r\n|\n)/, fn
      "\\" -> "\\\\"
      ";" -> "\\;"
      "," -> "\\,"
      "\r\n" -> "\\n"
      "\n" -> "\\n"
    end)
  end

  defp encode_param_value(atom) when is_atom(atom),
    do: atom |> to_string() |> String.upcase() |> escape_param_value()

  defp encode_param_value(string) when is_binary(string),
    do: string |> escape_param_value()

  defp encode_param_value(other),
    do: other |> to_string() |> escape_param_value()

  # param-value needs to be wrapped in double quotes if it contains
  # ";", ":", or "," and must never contain a double quote or any
  # control characters
  # ref: https://datatracker.ietf.org/doc/html/rfc5545#section-3.1
  defp escape_param_value(value) do
    # Not allowed to have a DQUOTE character in a value, but also
    # no way to properly escape, so replace it with single quote.
    # Then filter out all the CONTROL characters that are not allowed.
    cleaned_value =
      value
      |> String.replace(~s("), ~s('))
      |> String.replace(~r/[\x00-\x08\x0A-\x1F\x7F]/, "")

    cleaned_value
    |> String.contains?(~w(; : ,))
    |> case do
      true -> ~s("#{cleaned_value}")
      false -> cleaned_value
    end
  end

  defp encode_key(k) do
    k |> to_string() |> String.replace("_", "-") |> String.upcase()
  end

  # DO NOT encode block values
  defp encode_line("BEGIN:" <> _ = bin), do: bin

  defp encode_line(bin) do
    if String.length(bin) <= 75 do
      bin
    else
      {str_left, str_right} = String.split_at(bin, 75)
      str_left <> "\r\n " <> encode_line(str_right)
    end
  end
end
