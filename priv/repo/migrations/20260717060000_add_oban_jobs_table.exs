# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 12)

  # Oban.Migration.down/1 defaults to version 1, which would try to
  # completely reverse every intermediate schema change -- pin the same
  # version explicitly so `mix ecto.rollback` mirrors `up/0` exactly.
  def down, do: Oban.Migration.down(version: 12)
end
