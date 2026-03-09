defmodule Zockelo.SuperAdmins do
  @moduledoc """
  Context for managing super admins.

  Super admins are stored in the `super_admins` table.
  Email is encrypted at rest using AES-256-GCM (same key as Cloak vault).
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.SuperAdmins.SuperAdmin

  @doc """
  Creates a super admin record for `player_id` with `email` encrypted at rest.
  Returns `{:error, :already_exists}` if a record already exists for this player.
  """
  def create_super_admin(player_id, email, created_by \\ nil) do
    if super_admin?(player_id) do
      {:error, :already_exists}
    else
      encrypted_email = encrypt_email(email)

      %{player_id: player_id, encrypted_email: encrypted_email, created_by: created_by}
      |> SuperAdmin.changeset()
      |> Repo.insert()
    end
  end

  @doc "Returns all super admin records."
  def list_super_admins do
    Repo.all(SuperAdmin)
  end

  @doc "Returns true if `player_id` is a registered super admin."
  def super_admin?(player_id) do
    Repo.exists?(from sa in SuperAdmin, where: sa.player_id == ^player_id)
  end

  @doc "Removes the super admin record for `player_id`."
  def remove_super_admin(player_id) do
    case Repo.get(SuperAdmin, player_id) do
      nil -> {:error, :not_found}
      sa -> Repo.delete!(sa); :ok
    end
  end

  @doc "Decrypts the email field of a SuperAdmin record."
  def decrypt_email(%SuperAdmin{encrypted_email: ciphertext}) do
    Zockelo.Vault.decrypt(ciphertext)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp encrypt_email(email) do
    {:ok, encrypted} = Zockelo.Vault.encrypt(email)
    encrypted
  end
end
