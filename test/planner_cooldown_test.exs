# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.PlannerCooldownTest do
  use ExUnit.Case, async: true

  alias ArtifactsMmog.Planner

  test "cooldown_seconds/1 reads remaining_seconds from a successful action result" do
    result = %{"data" => %{"cooldown" => %{"remaining_seconds" => 12.5}}}
    assert Planner.cooldown_seconds(result) == 12.5
  end

  test "cooldown_seconds/1 returns nil when remaining_seconds is zero or absent" do
    assert Planner.cooldown_seconds(%{"data" => %{"cooldown" => %{"remaining_seconds" => 0}}}) ==
             nil

    assert Planner.cooldown_seconds(%{"data" => %{}}) == nil
    assert Planner.cooldown_seconds(%{"error" => %{"code" => 499}}) == nil
  end
end
