# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Release do
  @moduledoc """
  Release-safe tasks -- `mix ecto.migrate` isn't available inside a compiled
  release (no Mix). Run via `bin/artifacts_mmog eval "ArtifactsMmog.Release.migrate()"`.

  Migrates through `ArtifactsMmog.Repo`, before the agents start: a weft_fdb
  database admits one connection.
  """

  @app :artifacts_mmog

  def migrate do
    load_app()

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp load_app, do: Application.load(@app)
end
