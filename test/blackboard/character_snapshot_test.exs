# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterSnapshotTest do
  use ExUnit.Case, async: true

  alias ArtifactsMmog.Blackboard.CharacterSnapshot

  test "valid changeset requires only character_name" do
    changeset = CharacterSnapshot.changeset(%CharacterSnapshot{}, %{character_name: "hero"})
    assert changeset.valid?
  end

  test "carries scalar character fields and the plan cursor" do
    changeset =
      CharacterSnapshot.changeset(%CharacterSnapshot{}, %{
        character_name: "hero",
        hp: 90,
        max_hp: 100,
        x: 2,
        y: -4,
        task: "",
        inventory_max_items: 100,
        plan_cursor: 1
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :hp) == 90
    assert Ecto.Changeset.get_change(changeset, :plan_cursor) == 1
  end

  test "rejects a missing character_name" do
    changeset = CharacterSnapshot.changeset(%CharacterSnapshot{}, %{})
    refute changeset.valid?
  end
end
