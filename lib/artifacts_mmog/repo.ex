# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee

defmodule ArtifactsMmog.Repo do
  @moduledoc """
  Ecto repo backing the persistent blackboard (character snapshots, action
  outcomes).

  SQLite through `ecto_sqlite3`. With `:weftfdb_extension` configured, the
  database is a `file:<name>?vfs=weft_fdb` URI whose pages live in
  FoundationDB (datasource-store's `weftfdb` extension), and the pool holds
  one connection because every open of a weft_fdb database takes its fence.
  """

  use Ecto.Repo,
    otp_app: :artifacts_mmog,
    adapter: Ecto.Adapters.SQLite3

  @impl true
  def init(_context, config) do
    case Application.get_env(:artifacts_mmog, :weftfdb_extension) do
      nil ->
        {:ok, config}

      path ->
        with :ok <- load_extension(path) do
          {:ok, Keyword.put(config, :pool_size, 1)}
        end
    end
  end

  # The weft_fdb VFS registers process-wide, so it is loaded once on a throwaway connection.
  defp load_extension(path) do
    key = {__MODULE__, :weftfdb, path}

    if :persistent_term.get(key, false) do
      :ok
    else
      {:ok, conn} = Exqlite.Sqlite3.open(":memory:")

      try do
        with :ok <- Exqlite.Sqlite3.enable_load_extension(conn, true),
             :ok <-
               Exqlite.Sqlite3.execute(
                 conn,
                 "SELECT load_extension('#{String.replace(path, "'", "''")}')"
               ) do
          :persistent_term.put(key, true)
          :ok
        end
      after
        Exqlite.Sqlite3.close(conn)
      end
    end
  end
end
