# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.BlackboardTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias ArtifactsMmog.Repo
  alias ArtifactsMmog.Blackboard.{ActionOutcome, CharacterPlanStep, CharacterSnapshot}

  setup_all do
    dir = Path.join(System.tmp_dir!(), "mmog-blackboard-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    database = System.get_env("ARTIFACTS_MMOG_TEST_DATABASE") || Path.join(dir, "mmog.sqlite3")

    previous = Application.get_env(:artifacts_mmog, Repo, [])
    Application.put_env(:artifacts_mmog, Repo, Keyword.merge(previous, database: database))

    {:ok, pid} = Repo.start_link()
    Ecto.Migrator.run(Repo, :up, all: true, log: false)

    on_exit(fn ->
      if Process.alive?(pid), do: Supervisor.stop(pid)
      Application.put_env(:artifacts_mmog, Repo, previous)
      File.rm_rf!(dir)
    end)

    :ok
  end

  test "a snapshot upsert replaces its scalars" do
    for hp <- [10, 7] do
      %CharacterSnapshot{}
      |> CharacterSnapshot.changeset(%{character_name: "ana", hp: hp, max_hp: 10, x: 1, y: 2})
      |> Repo.insert!(
        on_conflict: {:replace, [:hp, :updated_at]},
        conflict_target: :character_name
      )
    end

    assert %CharacterSnapshot{hp: 7, max_hp: 10} = Repo.get(CharacterSnapshot, "ana")
  end

  test "plan step args and an outcome's raw response come back as written" do
    %CharacterSnapshot{}
    |> CharacterSnapshot.changeset(%{character_name: "bo", hp: 1})
    |> Repo.insert!()

    Repo.insert_all(CharacterPlanStep, [
      %{character_name: "bo", step_index: 0, action: "move", args: ["2", "3"]},
      %{character_name: "bo", step_index: 1, action: "rest", args: []}
    ])

    %ActionOutcome{}
    |> ActionOutcome.changeset(%{
      character_name: "bo",
      action: "move",
      args: ["2", "3"],
      status: "ok",
      raw_response: %{"data" => %{"cooldown" => %{"total_seconds" => 5}}}
    })
    |> Repo.insert!()

    steps =
      CharacterPlanStep
      |> where(character_name: "bo")
      |> order_by(:step_index)
      |> select([s], {s.action, s.args})
      |> Repo.all()

    assert steps == [{"move", ["2", "3"]}, {"rest", []}]

    assert %ActionOutcome{raw_response: %{"data" => %{"cooldown" => %{"total_seconds" => 5}}}} =
             Repo.one(from(o in ActionOutcome, where: o.character_name == "bo"))
  end

  test "deleting a snapshot deletes its plan steps" do
    %CharacterSnapshot{}
    |> CharacterSnapshot.changeset(%{character_name: "cy", hp: 1})
    |> Repo.insert!()

    Repo.insert_all(CharacterPlanStep, [
      %{character_name: "cy", step_index: 0, action: "fight", args: []}
    ])

    Repo.delete!(Repo.get(CharacterSnapshot, "cy"))
    assert [] == Repo.all(from(s in CharacterPlanStep, where: s.character_name == "cy"))
  end
end
