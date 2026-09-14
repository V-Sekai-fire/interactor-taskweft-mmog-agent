# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.CrdbCertWriter do
  @moduledoc """
  Writes this app's mTLS client certs from Fly secrets to disk.

  Mirrors `Gateway.CrdbCertWriter` from multiplayer-fabric-gateway, adapted
  to this app's own CockroachDB client identity. The app connects as the
  `artifacts_mmog_writer` database user for normal operation; a separate
  `artifacts_mmog_admin` identity (root/admin certs) is used only for
  running migrations, via `ArtifactsMmog.Repo.Migration`.

  Secrets expected (set by the CRDB app's cert-generation script):
    CRDB_CA_CRT              -- shared CA certificate (PEM)
    CRDB_CLIENT_WRITER_CRT   -- client cert for the `artifacts_mmog_writer` user (PEM)
    CRDB_CLIENT_WRITER_KEY   -- client key for the `artifacts_mmog_writer` user (PEM)
    CRDB_CLIENT_ADMIN_CRT    -- client cert for the `artifacts_mmog_admin` user (PEM)
    CRDB_CLIENT_ADMIN_KEY    -- client key for the `artifacts_mmog_admin` user (PEM)

  Certs are safe to rewrite on every deploy/boot.
  """

  @cert_dir "/tmp/crdb_certs"

  @doc "SSL opts for the writer (day-to-day app) connection."
  @spec writer_ssl_opts!() :: keyword()
  def writer_ssl_opts! do
    ssl_opts!(
      "client.writer.crt",
      "CRDB_CLIENT_WRITER_CRT",
      "client.writer.key",
      "CRDB_CLIENT_WRITER_KEY"
    )
  end

  @doc "SSL opts for the admin (migration) connection."
  @spec admin_ssl_opts!() :: keyword()
  def admin_ssl_opts! do
    ssl_opts!(
      "client.admin.crt",
      "CRDB_CLIENT_ADMIN_CRT",
      "client.admin.key",
      "CRDB_CLIENT_ADMIN_KEY"
    )
  end

  defp ssl_opts!(cert_name, cert_env, key_name, key_env) do
    ca_crt = System.fetch_env!("CRDB_CA_CRT")
    client_crt = System.fetch_env!(cert_env)
    client_key = System.fetch_env!(key_env)

    File.mkdir_p!(@cert_dir)

    [
      verify: :verify_peer,
      cacertfile: write!("ca.crt", ca_crt, 0o644),
      certfile: write!(cert_name, client_crt, 0o644),
      keyfile: write!(key_name, client_key, 0o600)
    ]
  end

  defp write!(name, content, mode) do
    path = Path.join(@cert_dir, name)
    File.write!(path, content)
    File.chmod!(path, mode)
    path
  end
end
