# interactor-taskweft-mmog-agent

An HTN-planning agent that plays characters in an online game through the game's HTTP API.

## What it is for

Each step reads a character's live state, builds a planning domain from it, plans with taskweft, and carries out the plan, looping on a goal such as gathering or fighting. A realtime orchestrator runs one tick loop per character and logs snapshots and outcomes to a database blackboard.

## Building and running

```sh
mix test
mix artifacts_mmog.run <character> <goal>
```

`mix artifacts_mmog.goals` lists the goals, and `mix artifacts_mmog.key set` stores the game's API token in the OS keychain.

## Licence

MIT. See [LICENSE](LICENSE).
