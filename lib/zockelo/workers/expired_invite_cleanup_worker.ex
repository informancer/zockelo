defmodule Zockelo.Workers.ExpiredInviteCleanupWorker do
  @moduledoc """
  Oban worker that deletes pending (invited, never activated) player profiles
  older than the configured retention window (default: 30 days).

  Scheduled per-tenant so individual tenants can have different cadences.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Projections.PlayerProfile

  @default_invite_ttl_days 30

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id} = args}) do
    ttl_days = Map.get(args, "invite_ttl_days", @default_invite_ttl_days)
    cutoff = DateTime.add(DateTime.utc_now(), -ttl_days * 24 * 3600, :second)

    Repo.delete_all(
      from p in PlayerProfile,
        where:
          p.tenant_id == ^tenant_id and
          p.status == "invited" and
          p.inserted_at < ^cutoff
    )

    :ok
  end
end
