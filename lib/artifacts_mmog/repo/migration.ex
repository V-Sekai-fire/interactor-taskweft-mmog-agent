# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migration do
  @moduledoc """
  Admin-privileged Ecto repo, used only for running migrations
  (`mix ecto.migrate`) via the `artifacts_mmog_admin` CRDB role.

  The app itself never uses this repo at runtime -- `ArtifactsMmog.Repo`
  (the `artifacts_mmog_writer` role, DML only) is what `ArtifactsMmog.Application`
  starts and what Oban/the blackboard schemas read and write through.
  """

  use Ecto.Repo,
    otp_app: :artifacts_mmog,
    adapter: Ecto.Adapters.Postgres
end
