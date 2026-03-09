defmodule Zockelo.ReleaseTasks do
  @moduledoc """
  Tasks callable from a Docker release via:

      ./bin/zockelo eval "Zockelo.ReleaseTasks.create_super_admin(\"email@example.com\")"
  """

  @doc """
  Creates a super admin with the given email address.

  Generates a new player_id UUID for the super admin. Idempotent per
  player_id — but since super admins are identified by player_id (not email),
  calling this multiple times with different UUIDs creates separate records.

  To be truly idempotent by email, this function checks if a super admin with
  a matching decrypted email already exists and returns `:already_exists`.
  """
  def create_super_admin(email) when is_binary(email) do
    load_app()

    existing = find_super_admin_by_email(email)

    if existing do
      IO.puts("Super admin with email #{email} already exists (player_id: #{existing.player_id}). Skipping.")
      :already_exists
    else
      player_id = Ecto.UUID.generate()

      case Zockelo.SuperAdmins.create_super_admin(player_id, email) do
        {:ok, sa} ->
          IO.puts("Super admin created: player_id=#{sa.player_id}")
          {:ok, sa}

        {:error, reason} ->
          IO.puts("Failed to create super admin: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp load_app do
    Application.ensure_all_started(:zockelo)
  end

  defp find_super_admin_by_email(email) do
    Zockelo.SuperAdmins.list_super_admins()
    |> Enum.find(fn sa ->
      case Zockelo.SuperAdmins.decrypt_email(sa) do
        {:ok, decrypted} -> decrypted == email
        _ -> false
      end
    end)
  end
end
