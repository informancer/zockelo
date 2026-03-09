defmodule Zockelo.Players do
  @moduledoc """
  Context for player management within a tenant.

  Covers invite, resend magic link, delete, and config update flows.
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.CommandedApp
  alias Zockelo.Crypto
  alias Zockelo.Crypto.PlayerDeletion
  alias Zockelo.Auth
  alias Zockelo.Projections.{PlayerProfile, TenantRead}

  alias Zockelo.Domain.Commands.{
    InvitePlayer,
    DeletePlayer,
    UpdateTenantConfig,
    UpdatePlayerName,
    ChangePlayerEmail
  }

  # ---------------------------------------------------------------------------
  # Invite
  # ---------------------------------------------------------------------------

  @doc """
  Invites a player by email to the given tenant.

  Generates a new player UUID and encryption key, dispatches `InvitePlayer`,
  and sends a magic link email. Returns `{:ok, player_id}`.
  """
  def invite_player(tenant_id, email, invited_by, role \\ "player") do
    player_id = Ecto.UUID.generate()

    {:ok, _raw_key} = Crypto.generate_player_key(player_id, tenant_id)
    {:ok, encrypted_email_bin} = Crypto.encrypt_field(player_id, email)
    # Base64-encode for JSON-safe storage in EventStore
    encrypted_email_b64 = Base.encode64(encrypted_email_bin)

    :ok = CommandedApp.dispatch(%InvitePlayer{
      player_id: player_id,
      tenant_id: tenant_id,
      encrypted_email: encrypted_email_b64,
      invited_by: invited_by,
      role: role
    })

    # Write the profile immediately for synchronous read consistency.
    # PlayerProfileProjection handles the event asynchronously (idempotent upsert).
    {:ok, _} = Repo.insert(PlayerProfile.changeset(%{
      player_id: player_id,
      tenant_id: tenant_id,
      encrypted_email: encrypted_email_bin,
      role: role,
      status: "invited"
    }), on_conflict: :nothing, conflict_target: :player_id)

    {:ok, _} = Auth.generate_magic_link(email, tenant_id, player_id)

    {:ok, player_id}
  end

  @doc """
  Resends a magic link to an already-invited (not yet activated) player.
  Fetches and decrypts their email from the player profile.
  """
  def resend_magic_link(player_id, tenant_id) do
    with %PlayerProfile{encrypted_email: enc} when not is_nil(enc) <-
           Repo.get(PlayerProfile, player_id),
         {:ok, email} <- Crypto.decrypt_field(player_id, enc) do
      {:ok, _} = Auth.generate_magic_link(email, tenant_id, player_id)
      :ok
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # Deletion
  # ---------------------------------------------------------------------------

  @doc """
  Permanently deletes a player: dispatches `DeletePlayer`, crypto-shreds keys,
  revokes sessions and tokens.
  """
  def delete_player(player_id, tenant_id, deleted_by) do
    # Void any pending/disputed games for this player before deleting.
    :ok = Zockelo.Games.void_player_games(player_id, tenant_id, deleted_by)

    :ok = CommandedApp.dispatch(%DeletePlayer{
      player_id: player_id,
      tenant_id: tenant_id,
      deleted_by: deleted_by
    })

    :ok = PlayerDeletion.execute(player_id, tenant_id)

    # Update profile immediately for synchronous read consistency.
    Repo.update_all(
      from(p in PlayerProfile, where: p.player_id == ^player_id),
      set: [status: "deleted"]
    )

    :ok
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Returns all PlayerProfile rows for `tenant_id`."
  def list_players(tenant_id) do
    Repo.all(from p in PlayerProfile, where: p.tenant_id == ^tenant_id)
  end

  @doc "Returns active (non-deleted) PlayerProfile rows for `tenant_id`."
  def list_active_players(tenant_id) do
    Repo.all(
      from p in PlayerProfile,
        where: p.tenant_id == ^tenant_id and p.status != "deleted"
    )
  end

  @doc "Returns invited (not yet activated) PlayerProfile rows for `tenant_id`."
  def list_invited_players(tenant_id) do
    Repo.all(
      from p in PlayerProfile,
        where: p.tenant_id == ^tenant_id and p.status == "invited"
    )
  end

  @doc "Returns a single player profile or nil."
  def get_player(player_id), do: Repo.get(PlayerProfile, player_id)

  # ---------------------------------------------------------------------------
  # Tenant config
  # ---------------------------------------------------------------------------

  @doc """
  Updates the tenant configuration by dispatching `UpdateTenantConfig`.
  """
  def update_tenant_config(tenant_id, changes, updated_by) do
    CommandedApp.dispatch(%UpdateTenantConfig{
      tenant_id: tenant_id,
      changes: changes,
      updated_by: updated_by
    })
  end

  @doc "Returns the TenantRead config map or a default."
  def get_tenant_config(tenant_id) do
    case Repo.get(TenantRead, tenant_id) do
      nil -> %{}
      tenant -> tenant.config || %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Profile updates
  # ---------------------------------------------------------------------------

  @doc """
  Updates a player's display name. Encrypts the name, dispatches `UpdatePlayerName`,
  and directly updates `player_profiles` for sync read consistency.
  """
  def update_player_name(player_id, tenant_id, name) do
    with {:ok, encrypted_name_bin} <- Crypto.encrypt_field(player_id, name) do
      encrypted_name_b64 = Base.encode64(encrypted_name_bin)

      :ok = CommandedApp.dispatch(%UpdatePlayerName{
        player_id: player_id,
        tenant_id: tenant_id,
        encrypted_name: encrypted_name_b64
      })

      Repo.update_all(
        from(p in PlayerProfile, where: p.player_id == ^player_id),
        set: [encrypted_name: encrypted_name_bin]
      )

      :ok
    end
  end

  @doc """
  Initiates an email change by sending a verification link to `new_email`.
  The new email is encrypted and stored in the verification token.
  On confirmation, call `confirm_email_change/2`.
  """
  def initiate_email_change(player_id, tenant_id, new_email) do
    with {:ok, encrypted_email_bin} <- Crypto.encrypt_field(player_id, new_email) do
      Auth.generate_email_change_link(player_id, tenant_id, new_email, encrypted_email_bin)
    end
  end

  @doc """
  Confirms an email change after verifying the token. Dispatches `ChangePlayerEmail`
  and directly updates `player_profiles`.
  """
  def confirm_email_change(player_id, tenant_id, encrypted_email_bin) do
    encrypted_email_b64 = Base.encode64(encrypted_email_bin)

    :ok = CommandedApp.dispatch(%ChangePlayerEmail{
      player_id: player_id,
      tenant_id: tenant_id,
      encrypted_email: encrypted_email_b64
    })

    Repo.update_all(
      from(p in PlayerProfile, where: p.player_id == ^player_id),
      set: [encrypted_email: encrypted_email_bin]
    )

    :ok
  end

  # ---------------------------------------------------------------------------
  # Role management
  # ---------------------------------------------------------------------------

  @doc "Grants tenant_admin role to a player (updates PlayerProfile directly)."
  def grant_admin(player_id, tenant_id) do
    set_role(player_id, tenant_id, "tenant_admin")
  end

  @doc "Revokes tenant_admin role, setting it back to 'player'."
  def revoke_admin(player_id, tenant_id) do
    set_role(player_id, tenant_id, "player")
  end

  defp set_role(player_id, tenant_id, role) do
    case Repo.get_by(PlayerProfile, player_id: player_id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      profile ->
        profile
        |> PlayerProfile.changeset(%{role: role})
        |> Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, _} = err -> err
        end
    end
  end
end
