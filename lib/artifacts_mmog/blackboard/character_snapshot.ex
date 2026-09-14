# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterSnapshot do
  @moduledoc """
  Persistent per-character scalar state: the same fields
  `ArtifactsMmog.Domain.build/2` reads off a live character map, plus how
  far plan execution has gotten and when the cooldown clears.

  Kept in Essential Tuple Normal Form (Darwen, Date & Fagin, ICDT 2012 --
  see CITATION.cff): every field here is a scalar functionally dependent on
  `character_name` alone. The inventory and the active plan are NOT
  embedded here as jsonb -- they're `CharacterInventoryItem` and
  `CharacterPlanStep`, each its own table with its own key.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ArtifactsMmog.Blackboard.{CharacterInventoryItem, CharacterPlanStep}

  @primary_key {:character_name, :string, autogenerate: false}
  schema "character_snapshots" do
    field(:hp, :integer)
    field(:max_hp, :integer)
    field(:x, :integer)
    field(:y, :integer)
    field(:task, :string)
    field(:inventory_max_items, :integer)
    field(:plan_cursor, :integer, default: 0)
    field(:cooldown_expires_at, :utc_datetime_usec)

    has_many(:inventory_items, CharacterInventoryItem, foreign_key: :character_name)
    has_many(:plan_steps, CharacterPlanStep, foreign_key: :character_name)

    timestamps(type: :utc_datetime_usec)
  end

  @fields ~w(character_name hp max_hp x y task inventory_max_items plan_cursor cooldown_expires_at)a

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @fields)
    |> validate_required([:character_name])
  end
end
