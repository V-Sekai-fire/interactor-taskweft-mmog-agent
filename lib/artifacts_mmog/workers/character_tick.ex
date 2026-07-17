# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Workers.CharacterTick do
  @moduledoc """
  Oban worker: "character X's next action is due."

  Each run executes exactly one real action against the ArtifactsMMO API,
  persists what happened to the blackboard, and reschedules itself at the
  server-reported cooldown expiry -- never estimated locally. At most one
  pending tick per character exists at a time (`unique` below).

  On failure (most notably a lost fight -- genuinely nondeterministic, not
  a bug) this records `asi` on the outcome and clears the active plan so
  the next tick re-plans from freshly fetched live state, rather than
  treating the failure as an Oban-level retry. Only real infra errors
  (the API/DB call itself raising) hit Oban's own retry/backoff.
  """

  use Oban.Worker,
    queue: :character_actions,
    unique: [fields: [:args], keys: [:character_name], states: :incomplete]

  alias ArtifactsMmog.{API, Domain, Planner, Repo}
  alias ArtifactsMmog.Blackboard.{ActionOutcome, CharacterSnapshot}

  @failure_backoff_seconds 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"character_name" => name, "tasks" => tasks}}) do
    with {:ok, char} <- fetch_char(name),
         snapshot <- load_snapshot(name),
         {:ok, step, plan, cursor} <- next_step(char, tasks, snapshot) do
      run_step(name, tasks, step, plan, cursor)
    else
      {:error, reason} ->
        record_outcome(name, %{"step" => "plan"}, "failed", %{"reason" => inspect(reason)})
        reschedule(name, tasks, @failure_backoff_seconds)
        :ok
    end
  end

  # ---------------------------------------------------------------------------

  defp fetch_char(name) do
    case API.my_characters() do
      %{"data" => chars} when is_list(chars) ->
        case Enum.find(chars, &(&1["name"] == name)) do
          nil -> {:error, "character #{name} not found"}
          char -> {:ok, char}
        end

      other ->
        {:error, "API error: #{inspect(other)}"}
    end
  end

  defp load_snapshot(name), do: Repo.get(CharacterSnapshot, name)

  # Resume an in-flight plan if one exists and isn't exhausted; otherwise
  # plan a fresh episode from the character's current live state.
  defp next_step(_char, _tasks, %CharacterSnapshot{
         active_plan: %{"steps" => plan},
         plan_cursor: cursor
       })
       when cursor < length(plan) do
    {:ok, Enum.at(plan, cursor), plan, cursor}
  end

  defp next_step(char, tasks, _snapshot) do
    with domain_json <- Domain.build(char, tasks),
         {:ok, plan_json} <- Taskweft.plan(domain_json),
         {:ok, plan} <- Jason.decode(plan_json) do
      case plan do
        [] -> {:error, "no_plan"}
        [step | _] -> {:ok, step, plan, 0}
      end
    end
  end

  defp run_step(name, tasks, [action | args], plan, cursor) do
    result = Planner.dispatch(name, action, args)

    if error?(result) do
      record_outcome(name, %{"action" => action, "args" => args}, "failed", %{"result" => result})
      # Force a fresh plan next tick rather than replaying a step that just
      # failed against now-stale assumptions about the world.
      clear_plan(name)
      reschedule(name, tasks, @failure_backoff_seconds)
    else
      record_outcome(name, %{"action" => action, "args" => args}, "ok", nil, result)
      advance_snapshot(name, plan, cursor + 1, result)

      delay = Planner.cooldown_seconds(result) || 0
      reschedule(name, tasks, delay)
    end

    :ok
  end

  defp error?(%{"error" => _}), do: true
  defp error?(_), do: false

  defp record_outcome(name, action, status, asi, http_response \\ nil) do
    %ActionOutcome{}
    |> ActionOutcome.changeset(%{
      character_name: name,
      action: action,
      status: status,
      http_response: http_response,
      asi: asi
    })
    |> Repo.insert()
  end

  defp advance_snapshot(name, plan, cursor, result) do
    cooldown_expires_at =
      case Planner.cooldown_seconds(result) do
        nil -> nil
        secs -> DateTime.add(DateTime.utc_now(), trunc(secs * 1000), :millisecond)
      end

    attrs = %{
      character_name: name,
      last_known_state: result,
      active_plan: if(cursor < length(plan), do: %{"steps" => plan}, else: nil),
      plan_cursor: if(cursor < length(plan), do: cursor, else: 0),
      cooldown_expires_at: cooldown_expires_at
    }

    upsert_snapshot(name, attrs)
  end

  defp clear_plan(name) do
    upsert_snapshot(name, %{character_name: name, active_plan: nil, plan_cursor: 0})
  end

  defp upsert_snapshot(name, attrs) do
    (Repo.get(CharacterSnapshot, name) || %CharacterSnapshot{character_name: name})
    |> CharacterSnapshot.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp reschedule(name, tasks, delay_seconds) do
    %{"character_name" => name, "tasks" => tasks}
    |> __MODULE__.new(schedule_in: max(trunc(delay_seconds), 0))
    |> Oban.insert()
  end
end
