# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.CharacterAgent do
  @moduledoc """
  Realtime per-character tick loop -- one GenServer per character, ticking
  on a short timer (~64/sec by default, `config :artifacts_mmog, :tick_interval_ms`).

  Every dispatch decision (is the cooldown clear? is there a queued plan
  step?) happens purely in-memory against this process's own state. There
  is no database round-trip, no job queue, and no polling interval on the
  hot path. A character whose next real action is due fires within one
  tick interval of its cooldown clearing, not after any external
  scheduler's poll delay.

  CockroachDB (when configured) is treated as an **unreliable environmental
  query, and as an async backup** -- never a source the agent depends on to
  make progress:

    - Writes (`persist_outcome/6`, `persist_snapshot/5`) are fire-and-forget,
      strictly after a real action completes, and swallow any DB error --
      losing an occasional write is fine, the server (ArtifactsMMO itself)
      remains the actual source of truth for a character's live state. The
      persisted schema is kept in Essential Tuple Normal Form (Darwen, Date
      & Fagin, ICDT 2012 -- see CITATION.cff): scalar character fields,
      inventory, and plan steps are their own tuples/tables, not jsonb
      blobs -- see the `ArtifactsMmog.Blackboard.*` schema moduledocs.
    - The one read (a prior snapshot + its plan steps, queried once on
      `init/1` to resume a restarted agent) is async too: fired off in a
      detached process, applied only if it arrives before the agent has
      made any real progress since boot (see
      `handle_info({:snapshot_loaded, ...}, _)`). A slow, stale, or
      entirely unreachable database just means a fresh start, never a
      blocked one.

  Planning (`Taskweft.plan/3`, which can take real wall-clock time) runs in
  a detached process so it never blocks the tick timer; the agent keeps
  ticking (and would still notice a cooldown clearing) while a plan is
  being computed.
  """

  use GenServer

  import Ecto.Query

  alias ArtifactsMmog.{Domain, Planner, Repo}

  alias ArtifactsMmog.Blackboard.{
    ActionOutcome,
    CharacterInventoryItem,
    CharacterPlanStep,
    CharacterSnapshot
  }

  @failure_backoff_ms 3_000

  defstruct [
    :name,
    :tasks,
    :tick_ms,
    active_plan: nil,
    plan_cursor: 0,
    cooldown_until: nil,
    planning: false
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start (or resume) the tick loop for `character_name` toward `tasks`."
  def start_link(character_name, tasks) do
    GenServer.start_link(__MODULE__, {character_name, tasks}, name: via(character_name))
  end

  @doc "Pid of the running agent for `character_name`, or `nil`."
  def whereis(character_name), do: GenServer.whereis(via(character_name))

  defp via(character_name), do: {:via, Registry, {ArtifactsMmog.Registry, character_name}}

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init({character_name, tasks}) do
    tick_ms = Application.get_env(:artifacts_mmog, :tick_interval_ms, 16)
    schedule_tick(tick_ms)
    load_snapshot_async(character_name)
    {:ok, %__MODULE__{name: character_name, tasks: tasks, tick_ms: tick_ms}}
  end

  @impl true
  def handle_info(:tick, state) do
    schedule_tick(state.tick_ms)
    now = DateTime.utc_now()

    cond do
      cooling_down?(state, now) -> {:noreply, state}
      queued_step?(state) -> {:noreply, dispatch_step(state, now)}
      state.planning -> {:noreply, state}
      true -> {:noreply, start_planning(state)}
    end
  end

  def handle_info({:plan_result, {:ok, plan}}, state) do
    persist_plan(state.name, plan)
    {:noreply, %{state | active_plan: plan, plan_cursor: 0, planning: false}}
  end

  def handle_info({:plan_result, {:error, reason}}, state) do
    persist_outcome(state.name, "plan", [], "failed", inspect(reason))
    now = DateTime.utc_now()

    {:noreply,
     %{
       state
       | planning: false,
         cooldown_until: DateTime.add(now, @failure_backoff_ms, :millisecond)
     }}
  end

  # A prior snapshot only matters if it arrives before the agent has done
  # anything of its own since boot -- otherwise it's stale by definition
  # and applying it would clobber real in-memory progress with old data.
  def handle_info(
        {:snapshot_loaded, {%CharacterSnapshot{} = snap, steps}},
        %{
          active_plan: nil,
          plan_cursor: 0,
          cooldown_until: nil,
          planning: false
        } = state
      ) do
    now = DateTime.utc_now()

    plan =
      case steps do
        [] -> nil
        steps -> Enum.map(steps, &[&1.action | &1.args])
      end

    cooldown_until =
      case snap.cooldown_expires_at do
        %DateTime{} = t -> if DateTime.compare(now, t) == :lt, do: t, else: nil
        _ -> nil
      end

    {:noreply,
     %{state | active_plan: plan, plan_cursor: snap.plan_cursor, cooldown_until: cooldown_until}}
  end

  # Either no snapshot existed, the query failed (CRDB unreachable -- fine,
  # it's just an unreliable environmental query), or the agent already moved
  # on since boot. Nothing to do either way.
  def handle_info({:snapshot_loaded, _}, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Tick logic
  # ---------------------------------------------------------------------------

  defp schedule_tick(tick_ms), do: Process.send_after(self(), :tick, tick_ms)

  defp cooling_down?(%{cooldown_until: nil}, _now), do: false
  defp cooling_down?(%{cooldown_until: until}, now), do: DateTime.compare(now, until) == :lt

  defp queued_step?(%{active_plan: plan, plan_cursor: cursor}) when is_list(plan),
    do: cursor < length(plan)

  defp queued_step?(_state), do: false

  defp dispatch_step(state, now) do
    [action | args] = Enum.at(state.active_plan, state.plan_cursor)
    result = Planner.dispatch(state.name, action, args)

    if error?(result) do
      persist_outcome(state.name, action, args, "failed", error_reason(result), result)

      %{
        state
        | active_plan: nil,
          plan_cursor: 0,
          cooldown_until: DateTime.add(now, @failure_backoff_ms, :millisecond)
      }
    else
      persist_outcome(state.name, action, args, "ok", nil, result)
      advance(state, result, now)
    end
  end

  defp advance(state, result, now) do
    plan = state.active_plan
    cursor = state.plan_cursor + 1
    done? = cursor >= length(plan)

    cooldown_secs = Planner.cooldown_seconds(result) || 0

    cooldown_until =
      if cooldown_secs > 0,
        do: DateTime.add(now, trunc(cooldown_secs * 1000), :millisecond),
        else: nil

    new_cursor = if done?, do: 0, else: cursor
    new_plan = if done?, do: nil, else: plan

    persist_snapshot(
      state.name,
      extract_character(result),
      new_cursor,
      cooldown_until,
      if(done?, do: [], else: nil)
    )

    %{state | active_plan: new_plan, plan_cursor: new_cursor, cooldown_until: cooldown_until}
  end

  defp extract_character(result), do: get_in(result, ["data", "character"]) || %{}

  defp error?(%{"error" => _}), do: true
  defp error?(_), do: false

  defp error_reason(%{"error" => %{"message" => msg}}) when is_binary(msg), do: msg
  defp error_reason(%{"error" => err}), do: inspect(err)
  defp error_reason(_), do: nil

  defp start_planning(state) do
    parent = self()
    name = state.name
    tasks = state.tasks

    spawn(fn -> send(parent, {:plan_result, plan_episode(name, tasks)}) end)

    %{state | planning: true}
  end

  defp plan_episode(name, tasks) do
    with {:ok, char} <- Planner.fetch_char(name),
         domain_json <- Domain.build(char, tasks),
         {:ok, plan_json} <- Taskweft.plan(domain_json),
         {:ok, plan} <- Jason.decode(plan_json) do
      case plan do
        [] -> {:error, :no_plan}
        _ -> {:ok, plan}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Persistence -- CockroachDB as an unreliable environmental query and an
  # async backup. Every read and write here is fire-and-forget from the
  # tick loop's perspective and swallows its own errors; nothing in this
  # section is allowed to affect whether an agent can make progress. Kept
  # in Essential Tuple Normal Form: no jsonb catch-all columns, only the
  # one deliberate exception (ActionOutcome.raw_response, ArtifactsMMO's
  # own external wire format).
  # ---------------------------------------------------------------------------

  defp load_snapshot_async(name) do
    if repo_up?() do
      parent = self()

      spawn(fn ->
        loaded =
          try do
            case Repo.get(CharacterSnapshot, name) do
              nil ->
                nil

              snapshot ->
                steps =
                  CharacterPlanStep
                  |> where(character_name: ^name)
                  |> order_by(:step_index)
                  |> Repo.all()

                {snapshot, steps}
            end
          rescue
            _ -> nil
          end

        send(parent, {:snapshot_loaded, loaded})
      end)
    end
  end

  defp persist_outcome(name, action, args, status, reason, raw_response \\ nil) do
    if repo_up?() do
      spawn(fn ->
        try do
          %ActionOutcome{}
          |> ActionOutcome.changeset(%{
            character_name: name,
            action: action,
            args: Enum.map(args, &to_string/1),
            status: status,
            reason: reason,
            raw_response: raw_response
          })
          |> Repo.insert()
        rescue
          _ -> :ok
        end
      end)
    end
  end

  # `plan` is `nil` (leave existing persisted steps alone -- nothing new to
  # write) or a list of decoded steps (replace persisted steps to match).
  defp persist_snapshot(name, character, plan_cursor, cooldown_until, plan) do
    if repo_up?() do
      spawn(fn ->
        try do
          Repo.transaction(fn ->
            upsert_snapshot_scalars(name, character, plan_cursor, cooldown_until)
            replace_inventory(name, character["inventory"])
            if plan, do: replace_plan_steps(name, plan)
          end)
        rescue
          _ -> :ok
        end
      end)
    end
  end

  defp persist_plan(name, plan) do
    if repo_up?() do
      spawn(fn ->
        try do
          replace_plan_steps(name, plan)
        rescue
          _ -> :ok
        end
      end)
    end
  end

  defp upsert_snapshot_scalars(name, character, plan_cursor, cooldown_until) do
    attrs =
      %{
        character_name: name,
        plan_cursor: plan_cursor,
        cooldown_expires_at: cooldown_until
      }
      |> Map.merge(character_scalar_attrs(character))

    %CharacterSnapshot{}
    |> CharacterSnapshot.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :hp,
           :max_hp,
           :x,
           :y,
           :task,
           :inventory_max_items,
           :plan_cursor,
           :cooldown_expires_at,
           :updated_at
         ]},
      conflict_target: :character_name
    )
  end

  defp character_scalar_attrs(character) do
    for field <- ~w(hp max_hp x y task inventory_max_items),
        value = Map.get(character, field),
        not is_nil(value),
        into: %{} do
      {String.to_existing_atom(field), value}
    end
  end

  defp replace_inventory(_name, nil), do: :ok

  defp replace_inventory(name, inventory) when is_list(inventory) do
    totals =
      inventory
      |> Enum.reject(&(is_nil(&1) || is_nil(&1["code"])))
      |> Enum.reduce(%{}, fn %{"code" => code, "quantity" => qty}, acc ->
        Map.update(acc, code, qty, &(&1 + qty))
      end)

    Repo.delete_all(from(i in CharacterInventoryItem, where: i.character_name == ^name))

    entries =
      for {code, qty} <- totals do
        %{character_name: name, item_code: code, quantity: qty}
      end

    if entries != [], do: Repo.insert_all(CharacterInventoryItem, entries)
  end

  defp replace_plan_steps(name, plan) do
    Repo.delete_all(from(s in CharacterPlanStep, where: s.character_name == ^name))

    entries =
      plan
      |> Enum.with_index()
      |> Enum.map(fn {[action | args], index} ->
        %{
          character_name: name,
          step_index: index,
          action: action,
          args: Enum.map(args, &to_string/1)
        }
      end)

    if entries != [], do: Repo.insert_all(CharacterPlanStep, entries)
  end

  defp repo_up?, do: Process.whereis(ArtifactsMmog.Repo) != nil
end
