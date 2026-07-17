# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Application do
  @moduledoc """
  OTP application entry point.

  Only starts the persistent-orchestrator stack (`ArtifactsMmog.Repo`,
  Oban) when CRDB secrets are present in the environment -- i.e. the
  deployed orchestrator release. Local one-off usage (`mix artifacts_mmog.run`,
  `mix artifacts_mmog.goals`, `mix test`) has no CRDB available and doesn't
  need it: those call `ArtifactsMmog.Planner`/`ArtifactsMmog.API` directly
  and never touch the blackboard.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = if orchestrator?(), do: orchestrator_children(), else: []

    Supervisor.start_link(children, strategy: :one_for_one, name: ArtifactsMmog.Supervisor)
  end

  defp orchestrator?, do: System.get_env("CRDB_CA_CRT") != nil

  defp orchestrator_children do
    [
      ArtifactsMmog.Repo,
      {Oban, Application.fetch_env!(:artifacts_mmog, Oban)}
    ]
  end
end
