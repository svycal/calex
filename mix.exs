defmodule Calex.MixProject do
  use Mix.Project

  def project do
    [
      app: :calex,
      description: "An Elixir library for encoding and decoding the iCal data format.",
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:timex, "~> 3.0"}
    ]
  end
end
