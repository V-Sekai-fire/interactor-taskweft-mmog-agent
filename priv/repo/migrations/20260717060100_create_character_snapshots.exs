# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migrations.CreateCharacterSnapshots do
  use Ecto.Migration

  # CockroachDB auto-commits DDL statements (confirmed by running this for
  # real: without this flag, the second migration in this run failed with
  # "transaction is not started" once CRDB had already closed the wrapping
  # transaction Ecto assumed it still controlled). Disabling Ecto's own DDL
  # transaction wrapper matches what the database actually does.
  @disable_ddl_transaction true

  # Schema kept in Essential Tuple Normal Form (Darwen, Date & Fagin, ICDT
  # 2012 -- see CITATION.cff): every attribute here is a scalar functionally
  # dependent on character_name alone. Repeating groups (inventory, the
  # active plan) are NOT embedded as jsonb blobs -- they're their own
  # tables (character_inventory_items, character_plan_steps), each with
  # its own key. There is no catch-all "state blob" column.
  def change do
    create table(:character_snapshots, primary_key: false) do
      add(:character_name, :string, primary_key: true)
      add(:hp, :integer)
      add(:max_hp, :integer)
      add(:x, :integer)
      add(:y, :integer)
      add(:task, :string)
      add(:inventory_max_items, :integer)
      add(:plan_cursor, :integer, null: false, default: 0)
      add(:cooldown_expires_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create table(:character_inventory_items, primary_key: false) do
      add(
        :character_name,
        references(:character_snapshots,
          column: :character_name,
          type: :string,
          on_delete: :delete_all
        ), primary_key: true)

      add(:item_code, :string, primary_key: true)
      add(:quantity, :integer, null: false)
    end

    create table(:character_plan_steps) do
      add(
        :character_name,
        references(:character_snapshots,
          column: :character_name,
          type: :string,
          on_delete: :delete_all
        ), null: false)

      add(:step_index, :integer, null: false)
      add(:action, :string, null: false)
      add(:args, {:array, :string}, null: false, default: [])
    end

    create(unique_index(:character_plan_steps, [:character_name, :step_index]))
  end
end
