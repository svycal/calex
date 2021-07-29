defmodule Calex.Encoder do
  @moduledoc false

  def encode!(props) do
    encode_value(props) <> "\r\n"
  end

  # encode multiple kwlist with begin/end
  defp encode_value({k, [[{_k, _v} | _] | _] = vals}) do
    vals
    |> Enum.map(&"BEGIN:#{encode_key(k)}\r\n#{encode_value(&1)}\r\nEND:#{encode_key(k)}")
    |> Enum.join("\r\n")
  end

  # encode kwlist with limited length lines
  defp encode_value([{_k, _v} | _] = props) do
    props |> Enum.map(&(&1 |> encode_value() |> encode_line())) |> Enum.join("\r\n")
  end

  # encode value with properties
  defp encode_value({k, [{_k, _v} | _] = v}) do
    encoded_props =
      v
      |> Keyword.delete(:value)
      |> Enum.map(fn {pk, pv} -> "#{encode_key(pk)}=#{encode_value(pv)}" end)
      |> Enum.join(";")

    "#{encode_key(k)};#{encoded_props}:#{encode_value(v[:value])}"
  end

  # encode standard key value
  defp encode_value({k, v}), do: "#{encode_key(k)}:#{encode_value(v)}"

  defp encode_value(%DateTime{} = dt),
    do: %{dt | microsecond: {0, 0}} |> Timex.to_datetime("UTC") |> Timex.format!("{ISO:Basic:Z}")

  defp encode_value(atom) when is_atom(atom), do: atom |> to_string() |> String.upcase()
  defp encode_value(other), do: other

  defp encode_key(k) do
    k |> to_string() |> String.replace("_", "-") |> String.upcase()
  end

  # DO NOT encode block values
  defp encode_line("BEGIN:" <> _ = bin), do: bin

  defp encode_line(bin) do
    if String.length(bin) <= 75 do
      bin
    else
      bin = String.replace(bin, ~r/[\r|\n]/, "\\n")
      {str_left, str_right} = String.split_at(bin, 75)
      str_left <> "\r\n " <> encode_line(str_right)
    end
  end
end