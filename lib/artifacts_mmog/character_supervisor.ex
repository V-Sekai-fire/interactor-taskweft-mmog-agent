# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.CharacterSupervisor do
  @moduledoc """
  DynamicSupervisor owning one `ArtifactsMmog.CharacterAgent` per running
  character. `:transient` restart: a crashed agent is restarted (its next
  tick re-fetches live state and resumes from the persisted/in-memory
  snapshot); an agent stopped intentionally via `stop_character/1` is not.
  """

  use DynamicSupervisor

  alias ArtifactsMmog.CharacterAgent

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  @doc "Start (or no-op if already running) the tick loop for `character_name`."
  @spec start_character(String.t(), list()) :: DynamicSupervisor.on_start_child()
  def start_character(character_name, tasks) do
    spec = %{
      id: {CharacterAgent, character_name},
      start: {CharacterAgent, :start_link, [character_name, tasks]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @doc "Stop `character_name`'s tick loop, if running."
  @spec stop_character(String.t()) :: :ok | {:error, :not_found}
  def stop_character(character_name) do
    case CharacterAgent.whereis(character_name) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  @doc "List character names with a currently running tick loop."
  @spec running() :: [String.t()]
  def running do
    Registry.select(ArtifactsMmog.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
