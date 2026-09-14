# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterInventoryItemTest do
  use ExUnit.Case, async: true

  alias ArtifactsMmog.Blackboard.CharacterInventoryItem

  test "valid changeset requires character_name, item_code, and quantity" do
    changeset =
      CharacterInventoryItem.changeset(%CharacterInventoryItem{}, %{
        character_name: "hero",
        item_code: "copper_ore",
        quantity: 12
      })

    assert changeset.valid?
  end

  test "rejects a missing quantity" do
    changeset =
      CharacterInventoryItem.changeset(%CharacterInventoryItem{}, %{
        character_name: "hero",
        item_code: "copper_ore"
      })

    refute changeset.valid?
  end
end
