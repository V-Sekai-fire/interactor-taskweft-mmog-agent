defmodule ArtifactsMmog.Planner do
  @moduledoc """
  HTN planning execution for ArtifactsMMO.

  Use `ArtifactsMmog.Domain.build/2` to produce the domain JSON,
  then `Taskweft.plan/1` to get a plan, then `execute/2` here to run it.
  `run/2` combines all three steps in one call.
  """

  alias ArtifactsMmog.{API, Domain}

  @doc """
  Plan and execute one episode for `char_name` toward `tasks`.

  `tasks` is a list of `[method, arg, ...]` arrays passed to `Domain.build/2`.
  Returns `{:ok, results}` or `{:error, reason}`.
  """
  def run(char_name, tasks) do
    with {:ok, char} <- fetch_char(char_name),
         domain_json <- Domain.build(char, tasks),
         {:ok, plan_json} <- Taskweft.plan(domain_json),
         {:ok, plan} <- Jason.decode(plan_json) do
      execute(char_name, plan)
    end
  end

  @doc """
  Execute an already-decoded plan (list of `[action, arg, ...]` steps).
  """
  def execute(char_name, steps) do
    results =
      Enum.map(steps, fn [action | args] ->
        IO.puts("[Planner] #{action}(#{Enum.join(args, ", ")})")
        result = dispatch(char_name, action, args)
        maybe_cooldown(result)
        {action, result}
      end)

    {:ok, results}
  end

  # ---------------------------------------------------------------------------
  # Private
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

  @doc """
  Dispatch a single decoded `[action, arg, ...]` step to the real API.

  Public (unlike `execute/2`, which also sleeps out the cooldown in-process)
  so a caller that wants to reschedule instead of blocking -- e.g.
  `ArtifactsMmog.Workers.CharacterTick` -- can execute exactly one step and
  read `cooldown_seconds/1` off the result itself.
  """
  def dispatch(name, "a_move", [_char, zone_id]) do
    zone_int = trunc_zone(zone_id)

    case Domain.zone_coords(zone_int) do
      {x, y} -> API.move(name, x, y)
      nil -> %{"error" => "unknown zone id #{zone_id}"}
    end
  end

  def dispatch(name, "a_gather", [_char | _]), do: API.gather(name)
  def dispatch(name, "a_fight", [_char | _]), do: API.fight(name)
  def dispatch(name, "a_rest", [_char | _]), do: API.rest(name)
  def dispatch(name, "a_accept_task", [_char | _]), do: API.accept_task(name)
  def dispatch(name, "a_complete_task", [_char | _]), do: API.complete_task(name)

  def dispatch(name, "a_bank_deposit", [_char | _]) do
    API.deposit_all(name)
  end

  def dispatch(name, action, args) do
    IO.puts("[Planner] unknown action: #{action}(#{inspect(args)})")
    %{"error" => "unknown action #{action}", "character" => name}
  end

  defp trunc_zone(id) when is_integer(id), do: id
  defp trunc_zone(id) when is_float(id), do: trunc(id)
  defp trunc_zone(id) when is_binary(id), do: String.to_integer(id)

  @doc "Extracts `remaining_seconds` from an API result's cooldown, if any."
  @spec cooldown_seconds(map()) :: number() | nil
  def cooldown_seconds(%{"data" => %{"cooldown" => %{"remaining_seconds" => secs}}})
      when is_number(secs) and secs > 0,
      do: secs

  def cooldown_seconds(_), do: nil

  defp maybe_cooldown(result) do
    case cooldown_seconds(result) do
      nil -> :ok
      secs -> Process.sleep(trunc(secs * 1000))
    end
  end
end
