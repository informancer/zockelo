defmodule Zockelo.Domain.Aggregates.Tenant do
  @moduledoc """
  Tenant aggregate. Manages the lifecycle of a league (registration, approval,
  configuration, and deletion).

  State transitions:
    nil → :pending  (RequestTenant)
    nil → :active   (RegisterTenant — direct creation)
    :pending → :active   (ApproveTenant)
    :pending → :rejected (RejectTenant)
    :active → :deletion_pending  (RequestTenantDeletion)
    :deletion_pending → :active  (CancelTenantDeletion)
    :deletion_pending → :deleted (TenantDeletionConfirmed + grace period)
  """

  alias Zockelo.Domain.Commands.{
    RegisterTenant,
    RequestTenant,
    ApproveTenant,
    RejectTenant,
    UpdateTenantConfig,
    RequestTenantDeletion,
    ConfirmTenantDeletion,
    CancelTenantDeletion
  }

  alias Zockelo.Domain.Events.{
    TenantRegistered,
    TenantRequested,
    TenantApproved,
    TenantRejected,
    TenantConfigUpdated,
    TenantDeletionRequested,
    TenantDeletionConfirmed,
    TenantDeletionCancelled
  }

  defstruct [
    :tenant_id,
    :slug,
    :name,
    :status,
    :config
  ]

  # ---------------------------------------------------------------------------
  # Command handlers
  # ---------------------------------------------------------------------------

  def execute(%__MODULE__{status: nil}, %RegisterTenant{} = cmd) do
    %TenantRegistered.V1{
      tenant_id: cmd.tenant_id,
      slug: cmd.slug,
      name: cmd.name,
      registered_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: nil}, %RequestTenant{} = cmd) do
    %TenantRequested.V1{
      tenant_id: cmd.tenant_id,
      slug: cmd.slug,
      name: cmd.name,
      requested_by_email: cmd.requested_by_email,
      requested_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :pending}, %ApproveTenant{} = cmd) do
    %TenantApproved.V1{
      tenant_id: cmd.tenant_id,
      approved_by: cmd.approved_by,
      approved_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :pending}, %RejectTenant{} = cmd) do
    %TenantRejected.V1{
      tenant_id: cmd.tenant_id,
      rejected_by: cmd.rejected_by,
      reason: cmd.reason,
      rejected_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :active}, %UpdateTenantConfig{} = cmd) do
    %TenantConfigUpdated.V1{
      tenant_id: cmd.tenant_id,
      changes: cmd.changes,
      updated_by: cmd.updated_by,
      updated_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :active}, %RequestTenantDeletion{} = cmd) do
    now = DateTime.utc_now()

    %TenantDeletionRequested.V1{
      tenant_id: cmd.tenant_id,
      requested_by: cmd.requested_by,
      grace_period_hours: cmd.grace_period_hours,
      execute_at: DateTime.add(now, cmd.grace_period_hours * 3600, :second),
      requested_at: now
    }
  end

  def execute(%__MODULE__{status: :deletion_pending}, %ConfirmTenantDeletion{} = cmd) do
    %TenantDeletionConfirmed.V1{
      tenant_id: cmd.tenant_id,
      confirmed_by: cmd.confirmed_by,
      confirmed_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :deletion_pending}, %CancelTenantDeletion{} = cmd) do
    %TenantDeletionCancelled.V1{
      tenant_id: cmd.tenant_id,
      cancelled_by: cmd.cancelled_by,
      cancelled_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: status}, cmd) do
    {:error, {:invalid_state, "Cannot execute #{inspect(cmd.__struct__)} in state #{inspect(status)}"}}
  end

  # ---------------------------------------------------------------------------
  # Event handlers (state mutation)
  # ---------------------------------------------------------------------------

  def apply(%__MODULE__{} = tenant, %TenantRegistered.V1{} = event) do
    %{tenant | tenant_id: event.tenant_id, slug: event.slug, name: event.name, status: :active}
  end

  def apply(%__MODULE__{} = tenant, %TenantRequested.V1{} = event) do
    %{tenant | tenant_id: event.tenant_id, slug: event.slug, name: event.name, status: :pending}
  end

  def apply(%__MODULE__{} = tenant, %TenantApproved.V1{}) do
    %{tenant | status: :active}
  end

  def apply(%__MODULE__{} = tenant, %TenantRejected.V1{}) do
    %{tenant | status: :rejected}
  end

  def apply(%__MODULE__{config: config} = tenant, %TenantConfigUpdated.V1{changes: changes}) do
    %{tenant | config: Map.merge(config || %{}, changes)}
  end

  def apply(%__MODULE__{} = tenant, %TenantDeletionRequested.V1{}) do
    %{tenant | status: :deletion_pending}
  end

  def apply(%__MODULE__{} = tenant, %TenantDeletionConfirmed.V1{}) do
    %{tenant | status: :deletion_confirmed}
  end

  def apply(%__MODULE__{} = tenant, %TenantDeletionCancelled.V1{}) do
    %{tenant | status: :active}
  end
end
