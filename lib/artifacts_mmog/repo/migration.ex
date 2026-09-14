# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo.Migration do
  @moduledoc """
  Admin-privileged Ecto repo, used only for running migrations
  (`mix ecto.migrate`) via the `artifacts_mmog_admin` CRDB role.

  The app itself never uses this repo at runtime -- `ArtifactsMmog.Repo`
  (the `artifacts_mmog_writer` role, DML only) is what `ArtifactsMmog.Application`
  starts and what the blackboard schemas read and write through.

  Needs `config :artifacts_mmog, ArtifactsMmog.Repo.Migration, priv: "priv/repo"`
  (see config.exs) -- Ecto derives a repo's default priv directory from its
  own last module segment (`Migration` -> `priv/migration`), not from
  `priv/repo/migrations` where the actual migration files live. Without
  that override, `Ecto.Migrator.run/3` silently finds zero migrations and
  reports "already up" against an empty database -- confirmed by running
  it for real (twice: `priv:` is app-env config, not a `use Ecto.Repo,`
  macro option, which the first fix attempt got wrong), not by reading docs.
  """

  use Ecto.Repo,
    otp_app: :artifacts_mmog,
    adapter: Ecto.Adapters.Postgres
end
