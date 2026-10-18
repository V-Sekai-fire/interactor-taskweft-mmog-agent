# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Application do
  @moduledoc """
  OTP application entry point.

  `ArtifactsMmog.Registry` and `ArtifactsMmog.CharacterSupervisor` always
  start -- they're pure in-memory OTP primitives, no database required, so
  `ArtifactsMmog.CharacterAgent` tick loops work in plain local dev/test too.

  `ArtifactsMmog.Repo` only starts when `ARTIFACTS_MMOG_DATABASE` is set
  (see `config/runtime.exs`). Agents check `Process.whereis(Repo)` before
  persisting and skip it when absent -- the database is write-behind
  logging, never required for an agent to run correctly.
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
    do: System.get_env("ARTIFACTS_MMOG_DATABASE") != nil
end
