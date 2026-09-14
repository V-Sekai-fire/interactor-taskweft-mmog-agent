# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterPlanStep do
  @moduledoc """
  One ordered step of a character's active plan. The essential-tuple
  decomposition of what used to be a plan array embedded in a jsonb blob --
  "step N of character X's plan is this action with these args" is its own
  fact, keyed by (character_name, step_index), not a repeating group.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "character_plan_steps" do
    field(:character_name, :string)
    field(:step_index, :integer)
    field(:action, :string)
    field(:args, {:array, :string}, default: [])
  end

  @fields ~w(character_name step_index action args)a

  def changeset(step, attrs) do
    step
    |> cast(attrs, @fields)
    |> validate_required([:character_name, :step_index, :action])
  end
end
