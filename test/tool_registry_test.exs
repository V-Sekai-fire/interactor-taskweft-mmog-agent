# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.ToolRegistryTest do
  use ExUnit.Case, async: false

  @tag :red
  test "game tools are registered and callable" do
    ArtifactsMmog.Tools.setup()
    assert {:ok, tools} = ArtifactsMmog.Tools.list()
    names = Enum.map(tools, & &1.name)
    assert "get_character_state" in names
  end
end
