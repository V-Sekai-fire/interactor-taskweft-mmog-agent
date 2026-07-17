# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migrations.CreateActionOutcomes do
  use Ecto.Migration

  # Essential Tuple Normal Form, same rationale as character_snapshots:
  # `action`/`args`/`reason` are real scalar/array attributes, not an
  # opaque jsonb blob. The one deliberate exception is `raw_response` --
  # ArtifactsMMO's own API payload, whose shape is dictated entirely by
  # that external system, not by this domain's own data model. Normalizing
  # someone else's wire format has no essential-tuple meaning here; it's
  # kept verbatim, clearly labeled, purely for debugging/audit.
  def change do
    create table(:action_outcomes) do
      add(
        :character_name,
        references(:character_snapshots,
          column: :character_name,
          type: :string,
          on_delete: :delete_all
        ),
        null: false
      )

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
