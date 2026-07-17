defmodule ArtifactsMmog.MixProject do
  use Mix.Project

  def project do
    [
      app: :artifacts_mmog,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ArtifactsMmog.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:taskweft_nif, "~> 0.2.0-dev"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      {:oban, "~> 2.19"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
