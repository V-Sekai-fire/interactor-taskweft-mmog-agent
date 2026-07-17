# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterSnapshotTest do
  use ExUnit.Case, async: true

  alias ArtifactsMmog.Blackboard.CharacterSnapshot

  test "valid changeset requires only character_name" do
    changeset = CharacterSnapshot.changeset(%CharacterSnapshot{}, %{character_name: "hero"})
    assert changeset.valid?
  end

  test "carries the active plan and cursor across a rebuild" do
    plan = [["a_move", "hero", 1], ["a_gather", "hero"]]

    changeset =
      CharacterSnapshot.changeset(%CharacterSnapshot{}, %{
        character_name: "hero",
        active_plan: %{"steps" => plan},
        plan_cursor: 1,
        last_known_state: %{"hp" => 90}
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :plan_cursor) == 1
    assert Ecto.Changeset.get_change(changeset, :active_plan) == %{"steps" => plan}
  end

  test "rejects a missing character_name" do
    changeset = CharacterSnapshot.changeset(%CharacterSnapshot{}, %{})
    refute changeset.valid?
  end
end
