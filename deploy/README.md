<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Local cluster (deploy/)

Brings up the whole realtime orchestrator locally under Podman Quadlet:
CockroachDB (single-node, insecure) plus the `artifacts-mmog` release,
talking to each other over a private Podman network by container name.

This is a **local dev cluster**, not a production deployment recipe --
insecure CRDB, no mTLS, no Fly.io. Production would reuse
`ArtifactsMmog.CrdbCertWriter`'s mTLS path (see its moduledoc), which this
setup deliberately doesn't exercise.

## Bring it up

From the repo root:

```sh
# 1. Build the release image.
podman build -t localhost/artifacts-mmog:latest -f deploy/Containerfile .

# 2. Install the Quadlet units (rootless, user-level -- requires linger
#    enabled so it survives logout: loginctl enable-linger $(whoami)).
mkdir -p ~/.config/containers/systemd ~/.config/artifacts-mmog
cp deploy/*.network deploy/*.volume deploy/*.container ~/.config/containers/systemd/
systemctl --user daemon-reload

# 3. Your ArtifactsMMO API key -- never committed.
echo "ARTIFACTS_MMOG_KEY=<your bearer token>" > ~/.config/artifacts-mmog/secrets.env
chmod 600 ~/.config/artifacts-mmog/secrets.env

# 4. Start CockroachDB first, create the database it doesn't create itself.
systemctl --user start crdb
until podman exec crdb ./cockroach sql --insecure -e 'SELECT 1' >/dev/null 2>&1; do sleep 1; done
podman exec crdb ./cockroach sql --insecure -e 'CREATE DATABASE IF NOT EXISTS artifacts_mmog_dev;'

# 5. Run migrations (one-shot, against the running image).
podman run --rm --network systemd-artifacts-mmog \
  -e DATABASE_URL=postgres://root@crdb:26257/artifacts_mmog_dev?sslmode=disable \
  localhost/artifacts-mmog:latest /app/bin/artifacts_mmog eval "ArtifactsMmog.Release.migrate()"

# 6. Start the orchestrator.
systemctl --user start artifacts-mmog
```

## Verify

```sh
systemctl --user status crdb artifacts-mmog
podman exec crdb ./cockroach sql --insecure -e 'SHOW TABLES FROM artifacts_mmog_dev;'
podman logs -f systemd-artifacts-mmog
```

## Start a character

There's no auto-start-on-boot wiring yet -- `ArtifactsMmog.CharacterAgent`
tick loops are started on demand via `ArtifactsMmog.CharacterSupervisor`:

```sh
podman exec -it systemd-artifacts-mmog /app/bin/artifacts_mmog remote

# In the remote shell:
ArtifactsMmog.CharacterSupervisor.start_character("YourCharName", [["rest_at_bank", "YourCharName"]])
```

Watch it persist real progress:

```sh
podman exec crdb ./cockroach sql --insecure -e \
  'SELECT character_name, plan_cursor, cooldown_expires_at FROM artifacts_mmog_dev.character_snapshots;'
```

## Tear down

```sh
systemctl --user stop artifacts-mmog crdb
systemctl --user disable artifacts-mmog crdb
rm ~/.config/containers/systemd/{artifacts-mmog.container,crdb.container,artifacts-mmog.network,crdb-data.volume}
systemctl --user daemon-reload
podman volume rm systemd-crdb-data   # drops persisted data
```
