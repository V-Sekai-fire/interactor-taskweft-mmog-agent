# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Application do
  @moduledoc """
  OTP application entry point.

  `ArtifactsMmog.Registry` and `ArtifactsMmog.CharacterSupervisor` always
  start -- they're pure in-memory OTP primitives, no database required, so
  `ArtifactsMmog.CharacterAgent` tick loops work in plain local dev/test too.

  `ArtifactsMmog.Repo` only starts when a database is actually configured
  -- either `CRDB_CA_CRT` (the deployed release's mTLS path, see
  `ArtifactsMmog.CrdbCertWriter`) or `DATABASE_URL` (the local/insecure-CRDB
  fallback, see `config/runtime.exs`) is present. Agents check
  `Process.whereis(Repo)` before persisting and simply skip it when absent
  -- the database is write-behind logging, never required for an agent to
  run correctly. Checking `CRDB_CA_CRT` alone was a real bug, caught by
  actually running the local Quadlet cluster (which uses `DATABASE_URL`,
  not `CRDB_CA_CRT`): the Repo silently never started at all, so every
  persistence write/read was a quiet no-op with no error anywhere.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if(database_configured?(), do: [ArtifactsMmog.Repo], else: []) ++
        [
          {Registry, keys: :unique, name: ArtifactsMmog.Registry},
          ArtifactsMmog.CharacterSupervisor
        ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ArtifactsMmog.Supervisor)
  end

  defp database_configured?,
    do: System.get_env("CRDB_CA_CRT") != nil or System.get_env("DATABASE_URL") != nil
end
