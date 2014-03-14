defmodule ElixirUds.Mixfile do
  use Mix.Project

  def project do
    [
      app:     :elixir_uds,
      version: "0.0.1",
      elixir:  "~> 0.12.4",
      deps:    deps,
    ]
  end

  def application do
    []
  end

  defp deps do
    []
  end
end
