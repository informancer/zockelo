defmodule Zockelo.Workers.MaintenanceBroadcastWorker do
  @moduledoc """
  Sends a maintenance announcement email to all active players who have
  maintenance_announcements notifications enabled.

  Enqueued by super admin from the system config panel.
  Includes List-Unsubscribe and List-Unsubscribe-Post headers.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  import Ecto.Query

  alias Zockelo.{Repo, Notifications}
  alias Zockelo.Notifications.Email
  alias Zockelo.Projections.PlayerProfile

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message" => message}}) do
    players =
      Repo.all(
        from p in PlayerProfile,
          where: p.status == "active" and is_nil(p.deleted_at),
          select: p
      )

    recipients =
      Enum.filter(players, fn p ->
        Notifications.enabled?(p.player_id, p.tenant_id, "maintenance_announcements")
      end)

    Logger.info("maintenance_broadcast.start",
      total_players: length(players),
      recipients: length(recipients)
    )

    Enum.each(recipients, fn player ->
      case Email.maintenance_announcement(player, message) do
        {:ok, _} -> :ok
        {:error, reason} ->
          Logger.warning("maintenance_broadcast.email_failed",
            player_id: player.player_id,
            reason: inspect(reason)
          )
      end
    end)

    Logger.info("maintenance_broadcast.complete", recipients: length(recipients))
    :ok
  end
end
