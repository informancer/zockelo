defmodule Zockelo.Workers.GameConfirmationWorker do
  @moduledoc """
  Oban worker that auto-confirms pending games past the tenant's
  `auto_confirm_after_hours` threshold.

  Runs on a cron schedule (every 15 minutes). Iterates all tenants,
  finds overdue pending games, and dispatches `ConfirmGame` for each.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.CommandedApp
  alias Zockelo.Projections.{TenantRead, GameRead}
  alias Zockelo.Domain.Commands.ConfirmGame

  @default_auto_confirm_hours 24

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    tenants = Repo.all(from t in TenantRead, where: t.status == "active")

    Enum.each(tenants, fn tenant ->
      hours =
        get_in(tenant.config || %{}, ["auto_confirm_after_hours"])
        |> parse_hours()

      cutoff = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

      overdue =
        Repo.all(
          from g in GameRead,
            where:
              g.tenant_id == ^tenant.id and
                g.status == "pending" and
                g.logged_at < ^cutoff
        )

      Enum.each(overdue, fn game ->
        CommandedApp.dispatch(%ConfirmGame{
          game_id: game.id,
          tenant_id: game.tenant_id,
          confirmed_by: "system"
        })
      end)
    end)

    :ok
  end

  defp parse_hours(nil), do: @default_auto_confirm_hours
  defp parse_hours(h) when is_integer(h), do: h
  defp parse_hours(h) when is_binary(h) do
    case Integer.parse(h) do
      {n, _} -> n
      :error -> @default_auto_confirm_hours
    end
  end
end
