defmodule Zockelo.Workers.InactiveAccountWarningWorker do
  @moduledoc """
  Oban worker (scheduled daily) that finds players within 30 days of the
  tenant's retention threshold and sends them a warning email.

  Respects the per-tenant `retention_period_days` config (default: 730).
  Only sends to active players whose `last_login_at` is known.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  import Ecto.Query

  alias Zockelo.{Repo, Crypto, Mailer, Notifications}
  alias Zockelo.Notifications.Email
  alias Zockelo.Projections.{PlayerProfile, TenantRead}

  @warning_window_days 30

  @impl true
  def perform(_job) do
    tenants = Repo.all(TenantRead)

    Enum.each(tenants, fn tenant ->
      retention_days = get_retention_days(tenant)
      warn_threshold = DateTime.add(DateTime.utc_now(), -(retention_days - @warning_window_days), :day)
      delete_threshold = DateTime.add(DateTime.utc_now(), -retention_days, :day)

      players =
        Repo.all(
          from p in PlayerProfile,
            where:
              p.tenant_id == ^tenant.id and
                p.status == "active" and
                not is_nil(p.last_login_at) and
                p.last_login_at < ^warn_threshold and
                p.last_login_at > ^delete_threshold
        )

      app_name = get_app_name(tenant)
      host = Application.get_env(:zockelo, :magic_link_base_url, "http://localhost:4000")
      login_url = "#{host}/#{tenant.slug}/login"

      Enum.each(players, fn profile ->
        if Notifications.enabled?(profile.player_id, tenant.id, "inactivity_warning") do
          with {:ok, email_addr} <- decrypt_email(profile) do
            days_remaining = days_until_deletion(profile.last_login_at, retention_days)
            email = Email.inactivity_warning(email_addr, app_name: app_name, login_url: login_url, days_remaining: days_remaining, locale: profile.locale || "en")
            Mailer.deliver(email)
          end
        end
      end)
    end)

    :ok
  end

  defp decrypt_email(%PlayerProfile{player_id: pid, encrypted_email: enc}) when not is_nil(enc) do
    Crypto.decrypt_field(pid, enc)
  end
  defp decrypt_email(_), do: {:error, :no_email}

  defp get_retention_days(%TenantRead{config: config}) do
    case get_in(config, ["retention_period_days"]) do
      nil -> 730
      days when is_integer(days) -> days
      days -> String.to_integer(to_string(days))
    end
  end

  defp get_app_name(%TenantRead{config: config}) do
    (config && Map.get(config, "app_name")) || "Zockelo"
  end

  defp days_until_deletion(%DateTime{} = last_login, retention_days) do
    deletion_at = DateTime.add(last_login, retention_days, :day)
    max(0, DateTime.diff(deletion_at, DateTime.utc_now(), :day))
  end
end
