# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.ActionOutcomeTest do
  use ExUnit.Case, async: true

  alias ArtifactsMmog.Blackboard.ActionOutcome

  test "valid changeset requires character_name, action, and status" do
    changeset =
      ActionOutcome.changeset(%ActionOutcome{}, %{
        character_name: "hero",
        action: %{"action" => "a_fight", "args" => []},
        status: "ok"
      })

    assert changeset.valid?
  end

  test "rejects a status outside the known set" do
    changeset =
      ActionOutcome.changeset(%ActionOutcome{}, %{
        character_name: "hero",
        action: %{},
        status: "bogus"
      })

    refute changeset.valid?
    assert %{status: ["is invalid"]} = errors_on(changeset)
  end

  test "asi is optional and only meaningful on failure" do
    changeset =
      ActionOutcome.changeset(%ActionOutcome{}, %{
        character_name: "hero",
        action: %{"action" => "a_fight"},
        status: "failed",
        asi: %{"reason" => "combat_loss", "monster" => "chicken"}
      })

    assert changeset.valid?

    assert Ecto.Changeset.get_change(changeset, :asi) == %{
             "reason" => "combat_loss",
             "monster" => "chicken"
           }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
