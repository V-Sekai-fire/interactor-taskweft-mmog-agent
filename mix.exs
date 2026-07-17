defmodule ArtifactsMmog.MixProject do
  use Mix.Project

  def project do
    [
      app: :artifacts_mmog,
      version: "0.1.0",
      elixir: "~> 1.17",
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:taskweft_nif, "~> 0.2.0-dev"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
