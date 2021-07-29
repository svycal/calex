defmodule Calex do
  @moduledoc """
  Calex is a library for encoding and decoding [iCalendar (iCal)](https://datatracker.ietf.org/doc/html/rfc5545) data.
  """

  @doc """
  Decodes a string of iCal data.
  """
  @spec decode!(data :: String.t()) :: Keyword.t() | no_return()
  def decode!(data) when is_binary(data) do
    Calex.Decoder.decode!(data)
  end

  def decode!(_) do
    raise(ArgumentError, message: "argument must be string")
  end

  @doc """
  Encodes iCal data into a string.
  """
  @spec encode!(data :: Keyword.t()) :: String.t() | no_return()
  def encode!(data) when is_list(data) do
    Calex.Encoder.encode!(data)
  end

  def encode!(_) do
    raise(ArgumentError, message: "argument must be keyword list")
  end
end
