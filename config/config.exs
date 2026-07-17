# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

import Config

config :artifacts_mmog, ecto_repos: [ArtifactsMmog.Repo, ArtifactsMmog.Repo.Migration]

# CockroachDB has no LISTEN/NOTIFY and no advisory locks, unlike Postgres --
# both defaults Oban relies on. Do not drop these two lines when touching
# this config; without them Oban either fails outright or silently falls
# back to slow polling-only dispatch.
config :artifacts_mmog, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.PG,
  peer: Oban.Peers.Global,
  repo: ArtifactsMmog.Repo,
  queues: [character_actions: 10],
  plugins: [Oban.Plugins.Pruner]
