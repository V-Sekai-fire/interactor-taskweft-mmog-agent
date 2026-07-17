# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migrations.CreateActionOutcomes do
  use Ecto.Migration

  # CockroachDB auto-commits DDL -- see the same flag in
  # 20260717060100_create_character_snapshots.exs for why this is required,
  # not optional, confirmed by running migrations for real.
  @disable_ddl_transaction true

  # Essential Tuple Normal Form, same rationale as character_snapshots:
  # `action`/`args`/`reason` are real scalar/array attributes, not an
  # opaque jsonb blob. The one deliberate exception is `raw_response` --
  # ArtifactsMMO's own API payload, whose shape is dictated entirely by
  # that external system, not by this domain's own data model. Normalizing
  # someone else's wire format has no essential-tuple meaning here; it's
  # kept verbatim, clearly labeled, purely for debugging/audit.
  #
  # `character_name` is NOT a foreign key to character_snapshots, unlike
  # the tables in the companion migration -- confirmed by running this for
  # real: a planning failure can legitimately happen before any snapshot
  # row exists for that character (nothing has ever been dispatched yet),
  # and an FK here silently rejected that insert (swallowed by the
  # unreliable-DB rescue in ArtifactsMmog.CharacterAgent, so the failure
  # never surfaced as an error -- it just quietly never got logged). This
  # is an independent event log, not a child of a snapshot that may not
  # exist yet.
  def change do
    create table(:action_outcomes) do
      add(:character_name, :string, null: false)
      add(:action, :string, null: false)
      add(:args, {:array, :string}, null: false, default: [])
      add(:status, :string, null: false)
      add(:reason, :string)
      add(:raw_response, :map)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:action_outcomes, [:character_name, :inserted_at]))
  end
end
