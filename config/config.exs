# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

import Config

config :artifacts_mmog, ecto_repos: [ArtifactsMmog.Repo, ArtifactsMmog.Repo.Migration]

# Ecto derives a repo's default :priv dir from its own last module segment
# ("Migration" -> priv/migration) -- override it to the same priv/repo
# directory ArtifactsMmog.Repo already uses by default, since that's where
# priv/repo/migrations actually lives. Confirmed necessary by running a real
# migration against CockroachDB: without this, Ecto.Migrator silently finds
# zero migrations and reports "already up" against an empty database.
config :artifacts_mmog, ArtifactsMmog.Repo.Migration, priv: "priv/repo"

# How often each ArtifactsMmog.CharacterAgent ticks, in milliseconds. Dispatch
# decisions (is the cooldown clear? is there a queued step?) happen entirely
# in-memory on this timer -- the database is write-behind logging only, never
# on the hot path. 16ms ~= 64 ticks/sec (round(1000/64), matching a
# Godot-engine-scale tick rate rather than the previous 10/sec).
config :artifacts_mmog, :tick_interval_ms, 16
import Config

config :instructor,
  adapter: Instructor.Adapters.OpenAI,
  openai: [
    api_key: System.get_env("OPENROUTER_API_KEY", "local"),
    api_url: "https://openrouter.ai/api"
  ]
