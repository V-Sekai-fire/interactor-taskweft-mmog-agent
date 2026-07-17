# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterSnapshot do
  @moduledoc """
  Persistent per-character state: last known live state, the active plan
  (if any) and how far execution has gotten through it, and when the
  character's cooldown clears.

  Lets a restarted node resume a character via `Taskweft.replan/3` from
  `plan_cursor` instead of throwing away in-flight progress and re-planning
  from scratch.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:character_name, :string, autogenerate: false}
  schema "character_snapshots" do
    field(:last_known_state, :map, default: %{})
    field(:active_plan, :map)
    field(:plan_cursor, :integer, default: 0)
    field(:cooldown_expires_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @fields ~w(character_name last_known_state active_plan plan_cursor cooldown_expires_at)a

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @fields)
    |> validate_required([:character_name])
  end
end
