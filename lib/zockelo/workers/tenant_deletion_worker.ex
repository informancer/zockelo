defmodule Zockelo.Workers.TenantDeletionWorker do
  @moduledoc """
  Oban worker that executes tenant deletion after the grace period.

  Bulk crypto-shreds all players in the tenant and marks the tenant as deleted.
  Safe to run multiple times — idempotent by design.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile}
  alias Zockelo.Crypto

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id}}) do
    case Repo.get(TenantRead, tenant_id) do
      nil ->
        :ok

      %TenantRead{status: "deleted"} ->
        :ok

      %TenantRead{} ->
        delete_tenant(tenant_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp delete_tenant(tenant_id) do
    player_ids =
      Repo.all(
        from p in PlayerProfile,
          where: p.tenant_id == ^tenant_id,
          select: p.player_id
      )

    Enum.each(player_ids, fn player_id ->
      Crypto.delete_player_key(player_id, tenant_id)
    end)

    Repo.update_all(
      from(t in TenantRead, where: t.id == ^tenant_id),
      set: [status: "deleted"]
    )

    :ok
  end
end
