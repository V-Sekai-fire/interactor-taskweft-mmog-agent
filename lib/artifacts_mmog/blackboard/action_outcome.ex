# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.ActionOutcome do
  @moduledoc """
  Append-only log of every action the orchestrator has executed against the
  real ArtifactsMMO API.

  `action`/`args`/`status`/`reason` are real scalar/array attributes, kept
  in Essential Tuple Normal Form (Darwen, Date & Fagin, ICDT 2012 -- see
  CITATION.cff), not an opaque jsonb blob. `raw_response` is the one
  deliberate exception: it's ArtifactsMMO's own API payload, whose shape is
  dictated entirely by that external system, not by this domain's data
  model -- normalizing someone else's wire format has no essential-tuple
  meaning here, so it's kept verbatim, purely for debugging/audit, and
  never read back by the agent itself.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "action_outcomes" do
    field(:character_name, :string)
    field(:action, :string)
    field(:args, {:array, :string}, default: [])
    field(:status, :string)
    field(:reason, :string)
    field(:raw_response, :map)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @fields ~w(character_name action args status reason raw_response)a
  @statuses ~w(ok failed unexpected)

  def changeset(outcome, attrs) do
    outcome
    |> cast(attrs, @fields)
    |> validate_required([:character_name, :action, :status])
    |> validate_inclusion(:status, @statuses)
  end
end
