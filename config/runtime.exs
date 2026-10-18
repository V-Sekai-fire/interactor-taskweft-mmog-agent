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
# SQLite, configured only when ARTIFACTS_MMOG_DATABASE is set (see
# ArtifactsMmog.Application). With ARTIFACTS_MMOG_WEFTFDB_EXTENSION set, the
# database is a weft_fdb URI such as `file:artifacts_mmog.v1?vfs=weft_fdb`
# and its pages live in FoundationDB; without it, a plain SQLite file.
# Plain `mix test`/`mix artifacts_mmog.run` need no database at all.
if extension = System.get_env("ARTIFACTS_MMOG_WEFTFDB_EXTENSION") do
  config :artifacts_mmog, :weftfdb_extension, extension
end

if database = System.get_env("ARTIFACTS_MMOG_DATABASE") do
  config :artifacts_mmog, ArtifactsMmog.Repo, database: database, pool_size: 1
end
