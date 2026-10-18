<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Local cluster (deploy/)

Brings up the whole realtime orchestrator locally under Podman Quadlet:
one FoundationDB process plus the `artifacts-mmog` release, talking to each
other over a private Podman network by container name. The release keeps
its SQLite database in FoundationDB through datasource-store's `weftfdb`
extension, which the image builds.

This is a **local dev cluster**, not a production deployment recipe: one
FoundationDB process, no TLS.

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

# 4. Start FoundationDB, configure a new database once, and copy its
#    cluster file out for the orchestrator.
systemctl --user start fdb
podman exec fdb fdbcli --exec "configure new single ssd" --timeout 30
until podman exec fdb fdbcli --exec "status minimal" --timeout 5 | grep -q available; do sleep 1; done
podman cp fdb:/var/fdb/fdb.cluster ~/.config/artifacts-mmog/fdb.cluster

# 5. Run migrations (one-shot, against the running image).
podman run --rm --network systemd-artifacts-mmog \
  -v ~/.config/artifacts-mmog/fdb.cluster:/etc/foundationdb/fdb.cluster:ro \
  -e ARTIFACTS_MMOG_DATABASE='file:artifacts_mmog_dev.v1?vfs=weft_fdb' \
  localhost/artifacts-mmog:latest /app/bin/artifacts_mmog eval "ArtifactsMmog.Release.migrate()"

# 6. Start the orchestrator.
systemctl --user start artifacts-mmog
```

## Verify

```sh
systemctl --user status fdb artifacts-mmog
podman exec fdb fdbcli --exec "status minimal"
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

Watch it persist real progress from the remote shell:

```elixir
ArtifactsMmog.Repo.all(ArtifactsMmog.Blackboard.CharacterSnapshot)
```

## Tear down

```sh
systemctl --user stop artifacts-mmog fdb
systemctl --user disable artifacts-mmog fdb
rm ~/.config/containers/systemd/{artifacts-mmog.container,fdb.container,artifacts-mmog.network,fdb-data.volume}
systemctl --user daemon-reload
podman volume rm systemd-fdb-data   # drops persisted data
```
