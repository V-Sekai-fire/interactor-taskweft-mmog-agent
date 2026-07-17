# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.CharacterInventoryItem do
  @moduledoc """
  One (character, item) -> quantity fact. The essential-tuple decomposition
  of what used to be an inventory list embedded in a jsonb blob on
  `CharacterSnapshot` -- "how many of this item does this character carry"
  is its own fact with its own natural key, not a repeating group.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "character_inventory_items" do
    field(:character_name, :string, primary_key: true)
    field(:item_code, :string, primary_key: true)
    field(:quantity, :integer)
  end

  @fields ~w(character_name item_code quantity)a

  def changeset(item, attrs) do
    item
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end
end
