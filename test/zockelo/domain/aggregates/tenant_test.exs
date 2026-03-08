defmodule Zockelo.Domain.Aggregates.TenantTest do
  use ExUnit.Case, async: true

  alias Zockelo.Domain.Aggregates.Tenant

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
    TenantApproved,
    TenantRejected,
    TenantConfigUpdated,
    TenantDeletionRequested,
    TenantDeletionConfirmed,
    TenantDeletionCancelled
  }

  @tenant_id "00000000-0000-0000-0000-000000000001"

  defp new_tenant, do: %Tenant{}

  defp apply_all(aggregate, events) when is_list(events),
    do: Enum.reduce(events, aggregate, &Tenant.apply(&2, &1))

  defp apply_all(aggregate, event), do: Tenant.apply(aggregate, event)

  # ---------------------------------------------------------------------------
  # RegisterTenant
  # ---------------------------------------------------------------------------

  describe "RegisterTenant" do
    test "creates an active tenant" do
      cmd = %RegisterTenant{tenant_id: @tenant_id, slug: "acme", name: "Acme FC"}
      assert %TenantRegistered.V1{tenant_id: @tenant_id, slug: "acme", name: "Acme FC"} =
               Tenant.execute(new_tenant(), cmd)
    end

    test "transitions state to :active after event applied" do
      cmd = %RegisterTenant{tenant_id: @tenant_id, slug: "acme", name: "Acme FC"}
      event = Tenant.execute(new_tenant(), cmd)
      tenant = Tenant.apply(new_tenant(), event)
      assert tenant.status == :active
      assert tenant.slug == "acme"
    end

    test "rejects second registration on existing tenant" do
      cmd = %RegisterTenant{tenant_id: @tenant_id, slug: "acme", name: "Acme FC"}
      event = Tenant.execute(new_tenant(), cmd)
      tenant = Tenant.apply(new_tenant(), event)

      assert {:error, _} = Tenant.execute(tenant, cmd)
    end
  end

  # ---------------------------------------------------------------------------
  # RequestTenant / ApproveTenant / RejectTenant
  # ---------------------------------------------------------------------------

  describe "RequestTenant → ApproveTenant" do
    setup do
      cmd = %RequestTenant{
        tenant_id: @tenant_id,
        slug: "acme",
        name: "Acme FC",
        requested_by_email: "bob@acme.com"
      }

      event = Tenant.execute(new_tenant(), cmd)
      tenant = Tenant.apply(new_tenant(), event)
      %{tenant: tenant}
    end

    test "tenant is in :pending state after request", %{tenant: tenant} do
      assert tenant.status == :pending
    end

    test "approving a pending request transitions to :active", %{tenant: tenant} do
      cmd = %ApproveTenant{tenant_id: @tenant_id, approved_by: "super-admin"}
      event = Tenant.execute(tenant, cmd)
      assert %TenantApproved.V1{} = event
      assert Tenant.apply(tenant, event).status == :active
    end

    test "rejecting a pending request transitions to :rejected", %{tenant: tenant} do
      cmd = %RejectTenant{tenant_id: @tenant_id, rejected_by: "super-admin", reason: "no capacity"}
      event = Tenant.execute(tenant, cmd)
      assert %TenantRejected.V1{} = event
      assert Tenant.apply(tenant, event).status == :rejected
    end

    test "cannot approve an already active tenant" do
      cmd_register = %RegisterTenant{tenant_id: @tenant_id, slug: "acme", name: "Acme FC"}
      active = new_tenant() |> apply_all(Tenant.execute(new_tenant(), cmd_register))
      assert {:error, _} = Tenant.execute(active, %ApproveTenant{tenant_id: @tenant_id, approved_by: "x"})
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateTenantConfig
  # ---------------------------------------------------------------------------

  describe "UpdateTenantConfig" do
    setup do
      tenant =
        new_tenant()
        |> apply_all(Tenant.execute(new_tenant(), %RegisterTenant{
          tenant_id: @tenant_id,
          slug: "acme",
          name: "Acme FC"
        }))

      %{tenant: tenant}
    end

    test "active tenant can update config", %{tenant: tenant} do
      cmd = %UpdateTenantConfig{
        tenant_id: @tenant_id,
        changes: %{rounds_to_win: 3, confirmation_mode: :confirmation},
        updated_by: "admin"
      }

      event = Tenant.execute(tenant, cmd)
      assert %TenantConfigUpdated.V1{changes: %{rounds_to_win: 3}} = event
      updated = Tenant.apply(tenant, event)
      assert updated.config.rounds_to_win == 3
      assert updated.config.confirmation_mode == :confirmation
    end

    test "config updates are merged, not replaced", %{tenant: tenant} do
      first_update = %TenantConfigUpdated.V1{
        tenant_id: @tenant_id,
        changes: %{rounds_to_win: 3},
        updated_by: "admin",
        updated_at: DateTime.utc_now()
      }

      second_update = %TenantConfigUpdated.V1{
        tenant_id: @tenant_id,
        changes: %{points_per_round: 10},
        updated_by: "admin",
        updated_at: DateTime.utc_now()
      }

      tenant_after = tenant |> apply_all(first_update) |> apply_all(second_update)
      assert tenant_after.config.rounds_to_win == 3
      assert tenant_after.config.points_per_round == 10
    end
  end

  # ---------------------------------------------------------------------------
  # Deletion flow
  # ---------------------------------------------------------------------------

  describe "tenant deletion flow" do
    setup do
      tenant =
        new_tenant()
        |> apply_all(Tenant.execute(new_tenant(), %RegisterTenant{
          tenant_id: @tenant_id,
          slug: "acme",
          name: "Acme FC"
        }))

      %{tenant: tenant}
    end

    test "requesting deletion transitions to :deletion_pending", %{tenant: tenant} do
      cmd = %RequestTenantDeletion{tenant_id: @tenant_id, requested_by: "admin", grace_period_hours: 48}
      event = Tenant.execute(tenant, cmd)
      assert %TenantDeletionRequested.V1{grace_period_hours: 48} = event
      assert Tenant.apply(tenant, event).status == :deletion_pending
    end

    test "confirming deletion transitions to :deletion_confirmed", %{tenant: tenant} do
      request_event = %TenantDeletionRequested.V1{
        tenant_id: @tenant_id,
        requested_by: "admin1",
        grace_period_hours: 48,
        execute_at: DateTime.utc_now(),
        requested_at: DateTime.utc_now()
      }

      pending = Tenant.apply(tenant, request_event)

      cmd = %ConfirmTenantDeletion{tenant_id: @tenant_id, confirmed_by: "admin2"}
      event = Tenant.execute(pending, cmd)
      assert %TenantDeletionConfirmed.V1{} = event
      assert Tenant.apply(pending, event).status == :deletion_confirmed
    end

    test "cancelling deletion restores :active status", %{tenant: tenant} do
      request_event = %TenantDeletionRequested.V1{
        tenant_id: @tenant_id,
        requested_by: "admin1",
        grace_period_hours: 48,
        execute_at: DateTime.utc_now(),
        requested_at: DateTime.utc_now()
      }

      pending = Tenant.apply(tenant, request_event)

      cmd = %CancelTenantDeletion{tenant_id: @tenant_id, cancelled_by: "admin2"}
      event = Tenant.execute(pending, cmd)
      assert %TenantDeletionCancelled.V1{} = event
      assert Tenant.apply(pending, event).status == :active
    end

    test "cannot request deletion when already deletion_pending", %{tenant: tenant} do
      request_event = %TenantDeletionRequested.V1{
        tenant_id: @tenant_id,
        requested_by: "admin1",
        grace_period_hours: 48,
        execute_at: DateTime.utc_now(),
        requested_at: DateTime.utc_now()
      }

      pending = Tenant.apply(tenant, request_event)
      cmd = %RequestTenantDeletion{tenant_id: @tenant_id, requested_by: "admin2", grace_period_hours: 48}
      assert {:error, _} = Tenant.execute(pending, cmd)
    end
  end
end
