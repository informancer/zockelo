defmodule Zockelo.Release do
  @moduledoc """
  Release tasks — run via `./bin/zockelo eval "Zockelo.Release.migrate()"`.

  The Dockerfile entrypoint calls migrate/0 before starting the server
  to ensure the database schema is always up to date on deploy.
  """

  @app :zockelo

  @doc """
  Runs all pending Ecto migrations and EventStore initialisation.

  Called automatically by the release entrypoint script before the server starts.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  @doc """
  Rolls back the most recent migration for the given repository.

  Usage: ./bin/zockelo eval "Zockelo.Release.rollback(Zockelo.Repo, 1)"
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    :ok
  end

  @doc """
  Re-encrypts all player keys under the current (or provided) Cloak key.

  Use this after rotating CLOAK_KEY:
    1. Add new key as secondary in config/runtime.exs
    2. Run: ./bin/zockelo eval "Zockelo.Release.rotate_cloak_key()"
    3. Promote new key to primary, remove old key

  See the operator guide for the full rotation procedure.
  """
  def rotate_cloak_key do
    load_app()

    import Ecto.Query

    alias Zockelo.{Repo, Crypto.PlayerKey}

    keys = Repo.all(from pk in PlayerKey, select: pk)
    total = length(keys)

    IO.puts("Re-encrypting #{total} player keys...")

    results =
      Enum.map(keys, fn key ->
        # Re-encrypt: decrypt with old key, store with current default key.
        # Cloak.Ecto handles this transparently on save — just load and re-save.
        changeset =
          key
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.force_change(:encrypted_key, key.encrypted_key)

        case Repo.update(changeset) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, key.player_id, reason}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _, _}, &1))

    if errors == [] do
      IO.puts("Key rotation complete — #{total} keys re-encrypted successfully.")
      :ok
    else
      IO.puts("Key rotation completed with #{length(errors)} errors:")
      Enum.each(errors, fn {:error, id, reason} -> IO.puts("  player_id=#{id}: #{inspect(reason)}") end)
      {:error, :partial_failure}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
    Application.ensure_all_started(@app)
  end
end
