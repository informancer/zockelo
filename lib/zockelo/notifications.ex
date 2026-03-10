defmodule Zockelo.Notifications do
  @moduledoc """
  Manages per-player notification preferences and unsubscribe token generation.

  Notification types:
  - Player types (configurable): game_logged, game_confirmed, game_disputed,
    game_auto_confirmed
  - Admin types (configurable, tenant_admin only): game_disputed_admin,
    new_player_via_invite_link
  - System types (non-configurable): inactivity_warning
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Notifications.NotificationPreference

  @player_types ~w(game_logged game_confirmed game_disputed game_auto_confirmed maintenance_announcements)
  @admin_types ~w(game_disputed_admin new_player_via_invite_link)
  @system_types ~w(inactivity_warning)

  def player_types, do: @player_types
  def admin_types, do: @admin_types
  def system_types, do: @system_types
  def all_configurable_types, do: @player_types ++ @admin_types

  # ---------------------------------------------------------------------------
  # Seeding defaults
  # ---------------------------------------------------------------------------

  @doc "Seeds all player notification defaults (enabled) on first activation."
  def seed_player_defaults(player_id, tenant_id) do
    now = DateTime.utc_now()

    rows =
      (@player_types ++ @system_types)
      |> Enum.map(fn type ->
        %{
          player_id: player_id,
          tenant_id: tenant_id,
          notification_type: type,
          enabled: true,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(NotificationPreference, rows, on_conflict: :nothing)
    :ok
  end

  @doc "Seeds admin notification defaults (enabled) when a player is granted tenant_admin."
  def seed_admin_defaults(player_id, tenant_id) do
    now = DateTime.utc_now()

    rows =
      @admin_types
      |> Enum.map(fn type ->
        %{
          player_id: player_id,
          tenant_id: tenant_id,
          notification_type: type,
          enabled: true,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(NotificationPreference, rows, on_conflict: :nothing)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Preference management
  # ---------------------------------------------------------------------------

  @doc "Returns all notification preferences for a player in a tenant."
  def list_preferences(player_id, tenant_id) do
    Repo.all(
      from p in NotificationPreference,
        where: p.player_id == ^player_id and p.tenant_id == ^tenant_id,
        order_by: p.notification_type
    )
  end

  @doc "Updates a single notification preference. Returns :ok."
  def set_preference(player_id, tenant_id, notification_type, enabled) do
    now = DateTime.utc_now()

    Repo.insert_all(
      NotificationPreference,
      [%{
        player_id: player_id,
        tenant_id: tenant_id,
        notification_type: notification_type,
        enabled: enabled,
        inserted_at: now,
        updated_at: now
      }],
      on_conflict: [set: [enabled: enabled, updated_at: now]],
      conflict_target: [:player_id, :tenant_id, :notification_type]
    )

    :ok
  end

  @doc "Returns true if the player has enabled this notification type (defaults to true if no record)."
  def enabled?(player_id, tenant_id, notification_type) do
    case Repo.get_by(NotificationPreference,
           player_id: player_id,
           tenant_id: tenant_id,
           notification_type: notification_type
         ) do
      nil -> true
      %NotificationPreference{enabled: enabled} -> enabled
    end
  end

  @doc "Disables a notification preference via unsubscribe link."
  def unsubscribe(player_id, tenant_id, notification_type) do
    set_preference(player_id, tenant_id, notification_type, false)
  end

  # ---------------------------------------------------------------------------
  # Unsubscribe tokens
  # ---------------------------------------------------------------------------

  @doc """
  Generates an HMAC-SHA256 unsubscribe token for the given player/tenant/type.
  The token signs `player_id:tenant_id:notification_type` with SECRET_KEY_BASE.
  """
  def unsubscribe_token(player_id, tenant_id, notification_type) do
    payload = "#{player_id}:#{tenant_id}:#{notification_type}"
    :crypto.mac(:hmac, :sha256, secret_key_base(), payload)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Verifies an unsubscribe token. Returns true if valid (constant-time compare).
  """
  def verify_unsubscribe_token(token, player_id, tenant_id, notification_type) do
    expected = unsubscribe_token(player_id, tenant_id, notification_type)

    try do
      :crypto.hash_equals(expected, token)
    rescue
      _ -> false
    end
  end

  @doc """
  Builds the full unsubscribe URL for embedding in List-Unsubscribe headers.
  """
  def unsubscribe_url(player_id, tenant_id, notification_type) do
    token = unsubscribe_token(player_id, tenant_id, notification_type)
    host = Application.get_env(:zockelo, :magic_link_base_url, "http://localhost:4000")

    params = URI.encode_query(%{
      player_id: player_id,
      tenant_id: tenant_id,
      type: notification_type,
      token: token
    })

    "#{host}/unsubscribe?#{params}"
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp secret_key_base do
    Application.get_env(:zockelo, ZockeloWeb.Endpoint)[:secret_key_base] ||
      Application.get_env(:zockelo, :secret_key_base, "dev_secret_key_base_replace_in_prod")
  end
end
