defmodule Zockelo.Auth do
  @moduledoc """
  Authentication context: magic links, sessions, invite links.
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Auth.{MagicLinkToken, Session, InviteLink, Email}
  alias Zockelo.Mailer

  # ---------------------------------------------------------------------------
  # Config defaults
  # ---------------------------------------------------------------------------

  @idle_timeout_seconds Application.compile_env(:zockelo, :session_idle_timeout, 8 * 3600)
  @absolute_max_seconds Application.compile_env(:zockelo, :session_max_lifetime, 7 * 24 * 3600)
  @token_ttl_seconds 15 * 60

  # ---------------------------------------------------------------------------
  # Magic links
  # ---------------------------------------------------------------------------

  @doc """
  Generates a magic link token for `player_id` in `tenant_id` and emails it
  to `email`. Returns `{:ok, raw_token}`.
  """
  def generate_magic_link(email, tenant_id, player_id) do
    raw_token = generate_token()
    token_hash = hash_token(raw_token)
    expires_at = DateTime.add(DateTime.utc_now(), @token_ttl_seconds, :second)

    {:ok, _} =
      Repo.insert(MagicLinkToken.changeset(%{
        player_id: player_id,
        tenant_id: tenant_id,
        token_hash: token_hash,
        expires_at: expires_at
      }))

    magic_url = build_magic_url(tenant_id, raw_token)

    email
    |> Email.magic_link(magic_url)
    |> Mailer.deliver()

    {:ok, raw_token}
  end

  @doc """
  Verifies a raw magic link token. Returns `{:ok, player_id}` on success or
  `{:error, reason}` where reason is `:not_found | :expired | :already_used`.
  """
  def verify_magic_link(raw_token) do
    token_hash = hash_token(raw_token)

    case Repo.get_by(MagicLinkToken, token_hash: token_hash) do
      nil ->
        {:error, :not_found}

      %MagicLinkToken{used_at: used_at} when not is_nil(used_at) ->
        {:error, :already_used}

      %MagicLinkToken{expires_at: expires_at} = token ->
        if DateTime.before?(DateTime.utc_now(), expires_at) do
          Repo.update_all(
            from(t in MagicLinkToken, where: t.id == ^token.id),
            set: [used_at: DateTime.utc_now()]
          )
          {:ok, token.player_id}
        else
          {:error, :expired}
        end
    end
  end

  @doc """
  Generates an email-change verification token. Sends a magic link to `new_email`.
  The token stores the new encrypted email so it can be applied on verification.
  Returns `{:ok, raw_token}`.
  """
  def generate_email_change_link(player_id, tenant_id, new_email, new_email_encrypted) do
    raw_token = generate_token()
    token_hash = hash_token(raw_token)
    expires_at = DateTime.add(DateTime.utc_now(), @token_ttl_seconds, :second)

    {:ok, _} =
      Repo.insert(MagicLinkToken.changeset(%{
        player_id: player_id,
        tenant_id: tenant_id,
        token_hash: token_hash,
        expires_at: expires_at,
        token_type: "email_change",
        new_email_encrypted: new_email_encrypted
      }))

    magic_url = build_email_change_url(tenant_id, raw_token)

    new_email
    |> Email.magic_link(magic_url)
    |> Mailer.deliver()

    {:ok, raw_token}
  end

  @doc """
  Verifies an email-change token. Returns `{:ok, player_id, new_email_encrypted}`
  or `{:error, reason}`.
  """
  def verify_email_change_token(raw_token) do
    token_hash = hash_token(raw_token)

    case Repo.get_by(MagicLinkToken, token_hash: token_hash, token_type: "email_change") do
      nil ->
        {:error, :not_found}

      %MagicLinkToken{used_at: used_at} when not is_nil(used_at) ->
        {:error, :already_used}

      %MagicLinkToken{expires_at: expires_at} = token ->
        if DateTime.before?(DateTime.utc_now(), expires_at) do
          Repo.update_all(
            from(t in MagicLinkToken, where: t.id == ^token.id),
            set: [used_at: DateTime.utc_now()]
          )
          {:ok, token.player_id, token.tenant_id, token.new_email_encrypted}
        else
          {:error, :expired}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Sessions
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new session for `player_id` / `tenant_id`.
  Returns `{:ok, session}`.
  """
  def create_session(player_id, tenant_id) do
    now = DateTime.utc_now()

    Repo.insert(Session.changeset(%{
      player_id: player_id,
      tenant_id: tenant_id,
      created_at: now,
      last_active_at: now,
      expires_at: DateTime.add(now, @absolute_max_seconds, :second)
    }))
  end

  @doc """
  Validates a session by ID. Checks absolute expiry and idle timeout.
  Returns `{:ok, session}` or `{:error, :not_found | :expired | :idle_timeout}`.
  """
  def validate_session(session_id) do
    case Repo.get(Session, session_id) do
      nil ->
        {:error, :not_found}

      session ->
        now = DateTime.utc_now()

        cond do
          DateTime.compare(now, session.expires_at) != :lt ->
            {:error, :expired}

          DateTime.diff(now, session.last_active_at, :second) > @idle_timeout_seconds ->
            {:error, :idle_timeout}

          true ->
            {:ok, session}
        end
    end
  end

  @doc """
  Refreshes the `last_active_at` timestamp on a session.
  """
  def touch_session(session_id) do
    Repo.update_all(
      from(s in Session, where: s.id == ^session_id),
      set: [last_active_at: DateTime.utc_now()]
    )
    :ok
  end

  @doc """
  Deletes a session (logout).
  """
  def delete_session(session_id) do
    Repo.delete_all(from s in Session, where: s.id == ^session_id)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Invite links
  # ---------------------------------------------------------------------------

  @doc """
  Generates a new invite link for `tenant_id`. `opts` may include `expires_at`.
  Returns `{:ok, token}`.
  """
  def generate_invite_link(tenant_id, created_by, opts) do
    token = generate_token()
    expires_at = Keyword.get(opts, :expires_at)

    {:ok, _} =
      Repo.insert(InviteLink.changeset(%{
        tenant_id: tenant_id,
        token: token,
        created_by: created_by,
        expires_at: expires_at
      }))

    {:ok, token}
  end

  @doc """
  Validates an invite link token for `tenant_id`.
  Returns `{:ok, tenant_id}` or `{:error, :not_found | :expired | :revoked}`.
  """
  def validate_invite_link(token, tenant_id) do
    case Repo.get_by(InviteLink, token: token, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      %InviteLink{revoked_at: revoked_at} when not is_nil(revoked_at) ->
        {:error, :revoked}

      %InviteLink{expires_at: expires_at} = link ->
        if is_nil(expires_at) or DateTime.before?(DateTime.utc_now(), expires_at) do
          {:ok, link.tenant_id}
        else
          {:error, :expired}
        end
    end
  end

  @doc """
  Revokes `old_token` and creates a new invite link for the tenant.
  Returns `{:ok, new_token}` or `{:error, :not_found}`.
  """
  def rotate_invite_link(tenant_id, old_token, created_by) do
    case Repo.get_by(InviteLink, token: old_token, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      old_link ->
        Repo.update_all(
          from(l in InviteLink, where: l.id == ^old_link.id),
          set: [revoked_at: DateTime.utc_now()]
        )
        generate_invite_link(tenant_id, created_by, [])
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp hash_token(raw_token) do
    :crypto.hash(:sha256, raw_token) |> Base.url_encode64(padding: false)
  end

  defp build_magic_url(_tenant_id, raw_token) do
    host = Application.get_env(:zockelo, :magic_link_base_url, "http://localhost:4000")
    "#{host}/auth/magic?token=#{raw_token}"
  end

  defp build_email_change_url(_tenant_id, raw_token) do
    host = Application.get_env(:zockelo, :magic_link_base_url, "http://localhost:4000")
    "#{host}/auth/email-change?token=#{raw_token}"
  end
end
