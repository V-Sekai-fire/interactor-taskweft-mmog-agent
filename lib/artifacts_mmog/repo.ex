# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo do
  @moduledoc """
  Ecto repo backing the persistent blackboard (character snapshots, action
  outcomes) and the Oban job queue.

  Plain `Ecto.Adapters.Postgres` (via `postgrex`) against CockroachDB --
  no special CockroachDB adapter needed, matching how the multiplayer-fabric
  `uro` and `gateway` services connect to CRDB in production.
  """

  use Ecto.Repo,
    otp_app: :artifacts_mmog,
    adapter: Ecto.Adapters.Postgres
end
