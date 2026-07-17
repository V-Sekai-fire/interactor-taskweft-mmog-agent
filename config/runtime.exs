import Config

dotenv = Path.expand("../.env", __DIR__)

if File.exists?(dotenv) do
  dotenv
  |> File.read!()
  |> String.split("\n", trim: true)
  |> Enum.reject(&String.starts_with?(&1, "#"))
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [k, v] when byte_size(k) > 0 ->
        if is_nil(System.get_env(k)), do: System.put_env(k, v)

      _ ->
        :ok
    end
  end)
end

# --- Blackboard / orchestrator database -------------------------------------
#
# Only configured when CRDB secrets are present (the deployed orchestrator
# release -- see ArtifactsMmog.Application.orchestrator?/0). Plain
# `mix test`/`mix artifacts_mmog.run` locally never reach this branch and
# need no database at all.
if System.get_env("CRDB_CA_CRT") do
  crdb_host = System.fetch_env!("CRDB_HOST")

  # CockroachDB-specific: `prepare: :unnamed` avoids named-prepared-statement
  # behavior CRDB doesn't handle the same way Postgres does; dropping this
  # causes real query failures, not just a perf regression.
  config :artifacts_mmog, ArtifactsMmog.Repo,
    hostname: crdb_host,
    port: 26_257,
    database: "artifacts_mmog",
    username: "artifacts_mmog_writer",
    prepare: :unnamed,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    parameters: [application_name: "artifacts_mmog_writer"],
    socket_options: [:inet6],
    ssl: true,
    ssl_opts:
      ArtifactsMmog.CrdbCertWriter.writer_ssl_opts!() ++
        [server_name_indication: String.to_charlist(crdb_host)]

  config :artifacts_mmog, ArtifactsMmog.Repo.Migration,
    hostname: crdb_host,
    port: 26_257,
    database: "artifacts_mmog",
    username: "artifacts_mmog_admin",
    prepare: :unnamed,
    pool_size: 2,
    parameters: [application_name: "artifacts_mmog_admin"],
    socket_options: [:inet6],
    ssl: true,
    ssl_opts:
      ArtifactsMmog.CrdbCertWriter.admin_ssl_opts!() ++
        [server_name_indication: String.to_charlist(crdb_host)]
else
  # Local dev/test default: a plain local Postgres (or CRDB in insecure
  # single-node mode) if the developer happens to be running one -- never
  # required, only used if `mix ecto.*`/`mix test` is invoked explicitly.
  local_url =
    System.get_env("DATABASE_URL") ||
      "postgres://postgres:postgres@localhost:5432/artifacts_mmog_#{config_env()}"

  config :artifacts_mmog, ArtifactsMmog.Repo, url: local_url, pool_size: 5
  config :artifacts_mmog, ArtifactsMmog.Repo.Migration, url: local_url, pool_size: 2
end
