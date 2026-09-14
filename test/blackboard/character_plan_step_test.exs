# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterPlanStepTest do
  use ExUnit.Case, async: true

  alias ArtifactsMmog.Blackboard.CharacterPlanStep

  test "valid changeset requires character_name, step_index, and action" do
    changeset =
      CharacterPlanStep.changeset(%CharacterPlanStep{}, %{
        character_name: "hero",
        step_index: 0,
        action: "a_move",
        args: ["hero", "1"]
      })

    assert changeset.valid?
  end

  test "args default to an empty list" do
    changeset =
      CharacterPlanStep.changeset(%CharacterPlanStep{}, %{
        character_name: "hero",
        step_index: 0,
        action: "a_rest"
      })

    assert changeset.valid?
  end

  test "rejects a missing action" do
    changeset =
      CharacterPlanStep.changeset(%CharacterPlanStep{}, %{character_name: "hero", step_index: 0})

    refute changeset.valid?
  end
end
