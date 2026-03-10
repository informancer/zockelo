defmodule Zockelo.Workers.InactiveAccountDeletionWorker do
  @moduledoc """
  Oban worker (scheduled daily) that deletes players who have exceeded the
  tenant's retention threshold and whose warning period has elapsed.

  Respects per-tenant `retention_period_days` config (default: 730).
  Warning period = 30 days after the warning email window.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  import Ecto.Query

  alias Zockelo.{Repo, Players}
  alias Zockelo.Projections.{PlayerProfile, TenantRead}

  @warning_window_days 30

  @impl true
  def perform(_job) do
    tenants = Repo.all(TenantRead)

    Enum.each(tenants, fn tenant ->
      retention_days = get_retention_days(tenant)
      # Must be past retention + warning window before we delete
      delete_threshold =
        DateTime.add(DateTime.utc_now(), -(retention_days + @warning_window_days), :day)

      players =
        Repo.all(
          from p in PlayerProfile,
            where:
              p.tenant_id == ^tenant.id and
                p.status == "active" and
                not is_nil(p.last_login_at) and
                p.last_login_at < ^delete_threshold
        )

      Enum.each(players, fn profile ->
        Players.delete_player(profile.player_id, tenant.id, "system")
      end)
    end)

    :ok
  end

  defp get_retention_days(%TenantRead{config: config}) do
    case get_in(config, ["retention_period_days"]) do
      nil -> 730
      days when is_integer(days) -> days
      days -> String.to_integer(to_string(days))
    end
  end
end
