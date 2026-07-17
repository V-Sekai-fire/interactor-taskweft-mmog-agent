# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migrations.CreateActionOutcomes do
  use Ecto.Migration

  def change do
    create table(:action_outcomes) do
      add(:character_name, :string, null: false)
      add(:action, :map, null: false)
      add(:status, :string, null: false)
      add(:http_response, :map)
      add(:asi, :map)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:action_outcomes, [:character_name, :inserted_at]))
  end
end
