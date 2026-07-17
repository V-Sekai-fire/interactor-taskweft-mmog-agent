# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Release do
  @moduledoc """
  Release-safe tasks -- `mix ecto.migrate` isn't available inside a compiled
  release (no Mix). Run via `bin/artifacts_mmog eval "ArtifactsMmog.Release.migrate()"`.

  Migrates through `ArtifactsMmog.Repo.Migration` specifically -- the
  admin-privileged repo (`artifacts_mmog_admin` in production; the same
  connection as `ArtifactsMmog.Repo` in local/insecure-CRDB dev, see
  `config/runtime.exs`), never the day-to-day writer repo the app itself
  runs queries through.
  """

  @app :artifacts_mmog

  def migrate do
    load_app()

    for repo <- Application.fetch_env!(@app, :ecto_repos), migration_repo?(repo) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp migration_repo?(ArtifactsMmog.Repo.Migration), do: true
  defp migration_repo?(_), do: false

  defp load_app, do: Application.load(@app)
end
