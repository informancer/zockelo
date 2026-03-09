defmodule Zockelo.Workers.TenantDeletionScheduler do
  @moduledoc """
  Commanded event handler that schedules a TenantDeletionWorker Oban job
  when TenantDeletionConfirmed is received.

  The `execute_at` from TenantDeletionRequested is not directly available here,
  so the job is scheduled immediately (the grace period / confirmation already
  acts as the gate). Adjust `scheduled_at` if a post-confirmation delay is needed.
  """

  use Commanded.Event.Handler,
    application: Zockelo.CommandedApp,
    name: __MODULE__

  alias Zockelo.Domain.Events.TenantDeletionConfirmed
  alias Zockelo.Workers.TenantDeletionWorker

  def handle(%TenantDeletionConfirmed.V1{tenant_id: tenant_id}, _metadata) do
    %{"tenant_id" => tenant_id}
    |> TenantDeletionWorker.new()
    |> Oban.insert()

    :ok
  end
end
