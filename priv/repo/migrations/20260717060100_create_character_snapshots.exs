# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migrations.CreateCharacterSnapshots do
  use Ecto.Migration

  def change do
    create table(:character_snapshots, primary_key: false) do
      add(:character_name, :string, primary_key: true)
      add(:last_known_state, :map, null: false, default: %{})
      add(:active_plan, :map)
      add(:plan_cursor, :integer, null: false, default: 0)
      add(:cooldown_expires_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
