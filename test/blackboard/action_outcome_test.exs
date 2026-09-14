# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Blackboard.ActionOutcomeTest do
  use ExUnit.Case, async: true

  alias ArtifactsMmog.Blackboard.ActionOutcome

  test "valid changeset requires character_name, action, and status" do
    changeset =
      ActionOutcome.changeset(%ActionOutcome{}, %{
        character_name: "hero",
        action: "a_fight",
        args: [],
        status: "ok"
      })

    assert changeset.valid?
  end

  test "rejects a status outside the known set" do
    changeset =
      ActionOutcome.changeset(%ActionOutcome{}, %{
        character_name: "hero",
        action: "a_fight",
        status: "bogus"
      })

    refute changeset.valid?
    assert %{status: ["is invalid"]} = errors_on(changeset)
  end

  test "reason is a plain scalar, only meaningful on failure" do
    changeset =
      ActionOutcome.changeset(%ActionOutcome{}, %{
        character_name: "hero",
        action: "a_fight",
        args: ["hero"],
        status: "failed",
        reason: "combat_loss"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :reason) == "combat_loss"
  end

  test "raw_response accepts the external API payload verbatim (the one deliberate jsonb exception)" do
    changeset =
      ActionOutcome.changeset(%ActionOutcome{}, %{
        character_name: "hero",
        action: "a_fight",
        status: "failed",
        raw_response: %{"error" => %{"code" => 499, "message" => "Cooldown active"}}
      })

    assert changeset.valid?
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
