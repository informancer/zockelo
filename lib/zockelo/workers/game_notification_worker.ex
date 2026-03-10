defmodule Zockelo.Workers.GameNotificationWorker do
  @moduledoc """
  Oban worker that sends game event notification emails to affected players.

  Args:
    - `event_type`: "game_logged" | "game_confirmed" | "game_disputed" | "game_auto_confirmed"
    - `game_id`: UUID of the game
    - `tenant_id`: UUID of the tenant
    - `player_ids`: list of player UUIDs to notify
    - `trigger_id`: deduplication key (typically the game_id + event_type)

  Unique per `{worker, trigger_id}` for 1 hour to prevent duplicate emails on retry.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 3600, fields: [:worker, :args], keys: [:trigger_id]]

  import Ecto.Query

  alias Zockelo.{Repo, Notifications, Mailer, Crypto}
  alias Zockelo.Notifications.Email
  alias Zockelo.Projections.{PlayerProfile, TenantRead}

  @impl true
  def perform(%Oban.Job{
        args: %{
          "event_type" => event_type,
          "game_id" => game_id,
          "tenant_id" => tenant_id,
          "player_ids" => player_ids
        }
      }) do
    tenant = Repo.get(TenantRead, tenant_id)
    if is_nil(tenant), do: :ok

    app_name = get_app_name(tenant)
    host = Application.get_env(:zockelo, :magic_link_base_url, "http://localhost:4000")
    game_url = "#{host}/#{tenant.slug}/games"
    reply_to = get_admin_reply_to(tenant_id)

    notification_type = event_type

    Enum.each(player_ids, fn player_id ->
      if Notifications.enabled?(player_id, tenant_id, notification_type) do
        with %PlayerProfile{encrypted_email: enc, locale: locale} when not is_nil(enc) <-
               Repo.get(PlayerProfile, player_id),
             {:ok, email_addr} <- Crypto.decrypt_field(player_id, enc) do
          unsub_url = Notifications.unsubscribe_url(player_id, tenant_id, notification_type)

          opts = [
            app_name: app_name,
            game_url: game_url,
            reply_to: reply_to,
            unsubscribe_url: unsub_url,
            locale: locale || "en"
          ]

          email = build_email(event_type, email_addr, opts)
          if email, do: Mailer.deliver(email)
        end
      end
    end)

    # Also notify tenant admins for disputed games
    if event_type == "game_disputed" do
      notify_admins_of_dispute(tenant_id, tenant, game_url, app_name, host)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_email("game_logged", to, opts), do: Email.game_logged(to, opts)
  defp build_email("game_confirmed", to, opts), do: Email.game_confirmed(to, opts)
  defp build_email("game_disputed", to, opts), do: Email.game_disputed(to, opts)
  defp build_email("game_auto_confirmed", to, opts), do: Email.game_auto_confirmed(to, opts)
  defp build_email(_, _to, _opts), do: nil

  defp notify_admins_of_dispute(tenant_id, tenant, game_url, app_name, host) do
    admin_url = "#{host}/#{tenant.slug}/admin"
    reply_to = get_admin_reply_to(tenant_id)

    admins =
      Repo.all(
        from p in PlayerProfile,
          where: p.tenant_id == ^tenant_id and p.role == "tenant_admin" and p.status == "active"
      )

    Enum.each(admins, fn admin ->
      if Notifications.enabled?(admin.player_id, tenant_id, "game_disputed_admin") do
        with %PlayerProfile{encrypted_email: enc} when not is_nil(enc) <-
               Repo.get(PlayerProfile, admin.player_id),
             {:ok, email_addr} <- Crypto.decrypt_field(admin.player_id, enc) do
          unsub_url =
            Notifications.unsubscribe_url(admin.player_id, tenant_id, "game_disputed_admin")

          Email.game_disputed_admin(email_addr,
            app_name: app_name,
            game_url: game_url,
            admin_url: admin_url,
            reply_to: reply_to,
            unsubscribe_url: unsub_url
          )
          |> Mailer.deliver()
        end
      end
    end)
  end

  defp get_app_name(nil), do: "Zockelo"
  defp get_app_name(%TenantRead{config: config}) when is_map(config) do
    Map.get(config, "app_name") || "Zockelo"
  end
  defp get_app_name(_), do: "Zockelo"

  defp get_admin_reply_to(tenant_id) do
    admin =
      Repo.one(
        from p in PlayerProfile,
          where: p.tenant_id == ^tenant_id and p.role == "tenant_admin" and p.status == "active",
          limit: 1
      )

    with %PlayerProfile{encrypted_email: enc, player_id: pid} when not is_nil(enc) <- admin,
         {:ok, email} <- Crypto.decrypt_field(pid, enc) do
      email
    else
      _ -> nil
    end
  end
end
