# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Tools do
  @moduledoc """
  Registers ArtifactsMMO game actions as ExMCP tools via Taskweft.GEPA.ToolRegistry.
  """

  alias Taskweft.GEPA.ToolRegistry
  alias ArtifactsMmog.API
  alias ExMCP.Server.Tools.Registry

  def setup do
    ToolRegistry.register(
      :get_character_state,
      fn %{"name" => name} ->
        {:ok, API.character(name)}
      end,
      description: "Fetch live character state from ArtifactsMMO",
      input_schema: %{type: "object", properties: %{name: %{type: "string"}}, required: ["name"]}
    )

    ToolRegistry.register(
      :move,
      fn %{"name" => name, "x" => x, "y" => y} ->
        {:ok, API.move(name, x, y)}
      end,
      description: "Move character to map coordinates",
      input_schema: %{
        type: "object",
        properties: %{name: %{type: "string"}, x: %{type: "integer"}, y: %{type: "integer"}},
        required: ["name", "x", "y"]
      }
    )

    ToolRegistry.register(
      :fight,
      fn %{"name" => name} ->
        {:ok, API.fight(name)}
      end,
      description: "Initiate fight at current location",
      input_schema: %{type: "object", properties: %{name: %{type: "string"}}, required: ["name"]}
    )

    ToolRegistry.register(
      :gather,
      fn %{"name" => name} ->
        {:ok, API.gather(name)}
      end,
      description: "Gather resources at current location",
      input_schema: %{type: "object", properties: %{name: %{type: "string"}}, required: ["name"]}
    )

    ToolRegistry.register(
      :rest,
      fn %{"name" => name} ->
        {:ok, API.rest(name)}
      end,
      description: "Rest to restore HP",
      input_schema: %{type: "object", properties: %{name: %{type: "string"}}, required: ["name"]}
    )

    :ok
  end

  def list do
    {:ok, Registry.list_tools(ToolRegistry)}
  end
end
