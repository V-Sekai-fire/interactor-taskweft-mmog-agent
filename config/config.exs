# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

import Config

config :artifacts_mmog, ecto_repos: [ArtifactsMmog.Repo, ArtifactsMmog.Repo.Migration]

# How often each ArtifactsMmog.CharacterAgent ticks, in milliseconds. Dispatch
# decisions (is the cooldown clear? is there a queued step?) happen entirely
# in-memory on this timer -- the database is write-behind logging only, never
# on the hot path. 16ms ~= 64 ticks/sec (round(1000/64), matching a
# Godot-engine-scale tick rate rather than the previous 10/sec).
config :artifacts_mmog, :tick_interval_ms, 16
