# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.CharacterAgentTest do
  use ExUnit.Case, async: false

  alias ArtifactsMmog.CharacterAgent

  # These exercise the pure cooldown-gating state machine via :sys state
  # injection, without hitting the real ArtifactsMMO API -- there's no HTTP
  # stubbing harness for ArtifactsMmog.API yet, so a real dispatch/planning
  # tick is not covered here. That's a real gap, flagged rather than faked.
  #
  # tick_interval_ms is overridden to something the real timer can never
  # fire within a test's lifetime. Every test that wants tick behavior
  # sends :tick manually. Without this, these tests raced the real timer:
  # confirmed live (not guessed) that at the real default (16ms/~64Hz) the
  # agent's own :tick frequently fires and starts planning before a test's
  # explicit `send(pid, {:snapshot_loaded, ...})` is even sent, flipping
  # `planning: true` first and making the resume guard clause reject the
  # test's snapshot as "late" -- a real race, not just test flakiness (see
  # the CharacterAgent moduledoc's "Known limitation" section).
  setup_all do
    original = Application.get_env(:artifacts_mmog, :tick_interval_ms)
    Application.put_env(:artifacts_mmog, :tick_interval_ms, 60_000)

    on_exit(fn ->
      if original, do: Application.put_env(:artifacts_mmog, :tick_interval_ms, original)
    end)

    :ok
  end

  setup do
    name = "test_char_#{System.unique_integer([:positive])}"

    {:ok, pid} =
      start_supervised(%{
        id: {CharacterAgent, name},
        start: {CharacterAgent, :start_link, [name, []]}
      })

    %{pid: pid, name: name}
  end

  test "a fresh agent has no cooldown and no queued plan", %{pid: pid} do
    state = :sys.get_state(pid)
    assert state.cooldown_until == nil
    assert state.active_plan == nil
    assert state.plan_cursor == 0
  end

  test "ticking while cooldown_until is in the future leaves state untouched", %{pid: pid} do
    future = DateTime.add(DateTime.utc_now(), 30, :second)
    :sys.replace_state(pid, &%{&1 | cooldown_until: future, planning: true})

    send(pid, :tick)
    # allow the message to be processed
    :sys.get_state(pid)

    state = :sys.get_state(pid)
    assert state.cooldown_until == future
    # `planning: true` proves the tick short-circuited on the cooldown check
    # and never reached the "start planning" branch, which would flip it.
    assert state.planning == true
  end

  test "ticking after cooldown clears falls through to planning", %{pid: pid} do
    past = DateTime.add(DateTime.utc_now(), -1, :second)
    :sys.replace_state(pid, &%{&1 | cooldown_until: past, planning: false})

    send(pid, :tick)

    state = :sys.get_state(pid)
    assert state.planning == true
  end

  test "whereis/1 resolves a running agent by character name", %{pid: pid, name: name} do
    assert CharacterAgent.whereis(name) == pid
  end

  describe "resuming from an async-loaded snapshot" do
    alias ArtifactsMmog.Blackboard.{CharacterPlanStep, CharacterSnapshot}

    test "applies a fresh snapshot + its plan steps when the agent hasn't acted since boot", %{
      pid: pid
    } do
      steps = [
        %CharacterPlanStep{step_index: 0, action: "a_move", args: ["hero", "1"]},
        %CharacterPlanStep{step_index: 1, action: "a_gather", args: ["hero"]}
      ]

      future = DateTime.add(DateTime.utc_now(), 10, :second)
      snap = %CharacterSnapshot{plan_cursor: 1, cooldown_expires_at: future}

      send(pid, {:snapshot_loaded, {snap, steps}})
      state = :sys.get_state(pid)

      assert state.active_plan == [["a_move", "hero", "1"], ["a_gather", "hero"]]
      assert state.plan_cursor == 1
      assert state.cooldown_until == future
    end

    test "ignores an already-expired cooldown from a stale snapshot", %{pid: pid} do
      past = DateTime.add(DateTime.utc_now(), -30, :second)
      snap = %CharacterSnapshot{plan_cursor: 0, cooldown_expires_at: past}

      send(pid, {:snapshot_loaded, {snap, []}})
      state = :sys.get_state(pid)

      assert state.cooldown_until == nil
    end

    test "a snapshot with no persisted plan steps resumes with no active plan", %{pid: pid} do
      snap = %CharacterSnapshot{plan_cursor: 0, cooldown_expires_at: nil}

      send(pid, {:snapshot_loaded, {snap, []}})
      state = :sys.get_state(pid)

      assert state.active_plan == nil
    end

    test "ignores a late snapshot once the agent has already made progress", %{pid: pid} do
      :sys.replace_state(pid, &%{&1 | planning: true})

      steps = [%CharacterPlanStep{step_index: 0, action: "a_rest", args: ["hero"]}]
      snap = %CharacterSnapshot{plan_cursor: 0, cooldown_expires_at: nil}

      send(pid, {:snapshot_loaded, {snap, steps}})
      state = :sys.get_state(pid)

      # Untouched -- the guard clause requires a pristine (never-ticked) state.
      assert state.active_plan == nil
      assert state.planning == true
    end

    test "a missing or unreadable snapshot (nil) is a harmless no-op", %{pid: pid} do
      send(pid, {:snapshot_loaded, nil})
      state = :sys.get_state(pid)

      assert state.active_plan == nil
      assert state.cooldown_until == nil
    end
  end
end
