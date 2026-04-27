# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.RunnerGEPATest do
  use ExUnit.Case, async: true

  @tag :red
  test "reflect_and_evolve/2 returns updated instructions given a failed step result" do
    replan_result = %{"recovered" => false, "fail_step" => 0, "failed_action" => "a_fight", "new_plan" => []}
    instructions = ["fight chickens near bank", "rest when hp low"]
    assert {:ok, evolved} = ArtifactsMmog.Runner.reflect_and_evolve(replan_result, instructions)
    assert is_list(evolved) and length(evolved) > 0
  end
end
