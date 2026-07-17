# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.ActionOutcome do
  @moduledoc """
  Append-only log of every action the orchestrator has executed against the
  real ArtifactsMMO API.

  A failed outcome (e.g. a lost fight -- genuinely nondeterministic, not a
  bug) carries `asi` ("Actionable Side Information"): what went wrong, for
  a future reflective/GEPA-style pass to read. This is real persistent
  memory the bare `ArtifactsMmog.Runner` loop never had.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "action_outcomes" do
    field(:character_name, :string)
    field(:action, :map)
    field(:status, :string)
    field(:http_response, :map)
    field(:asi, :map)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @fields ~w(character_name action status http_response asi)a
  @statuses ~w(ok failed unexpected)

  def changeset(outcome, attrs) do
    outcome
    |> cast(attrs, @fields)
    |> validate_required([:character_name, :action, :status])
    |> validate_inclusion(:status, @statuses)
  end
end
