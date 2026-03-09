defmodule Zockelo.Projections.TenantProjectionTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Projections.{TenantProjection, TenantRead}
  alias Zockelo.Repo

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

  @tenant_id "00000000-0000-0000-0000-000000000001"

  defp meta, do: %{handler_name: "TenantProjection", event_number: System.unique_integer([:positive, :monotonic])}
  defp handle(event), do: TenantProjection.handle(event, meta())

  describe "TenantRegistered" do
    test "creates an active tenant row" do
      :ok = handle(%TenantRegistered.V1{
        tenant_id: @tenant_id, slug: "acme", name: "Acme FC",
        registered_at: DateTime.utc_now()
      })

      tenant = Repo.get(TenantRead, @tenant_id)
      assert tenant.slug == "acme"
      assert tenant.status == "active"
    end
  end

  describe "TenantRequested" do
    test "creates a pending tenant row" do
      :ok = handle(%TenantRequested.V1{
        tenant_id: @tenant_id, slug: "acme", name: "Acme FC",
        requested_by_email: "bob@acme.com", requested_at: DateTime.utc_now()
      })

      tenant = Repo.get(TenantRead, @tenant_id)
      assert tenant.status == "pending"
    end
  end

  describe "TenantApproved" do
    setup do
      :ok = handle(%TenantRequested.V1{
        tenant_id: @tenant_id, slug: "acme", name: "Acme FC",
        requested_by_email: "bob@acme.com", requested_at: DateTime.utc_now()
      })
      :ok
    end

    test "transitions tenant to active" do
      :ok = handle(%TenantApproved.V1{
        tenant_id: @tenant_id, approved_by: "super", approved_at: DateTime.utc_now()
      })
      assert Repo.get(TenantRead, @tenant_id).status == "active"
    end
  end

  describe "TenantRejected" do
    setup do
      :ok = handle(%TenantRequested.V1{
        tenant_id: @tenant_id, slug: "acme", name: "Acme FC",
        requested_by_email: "bob@acme.com", requested_at: DateTime.utc_now()
      })
      :ok
    end

    test "transitions tenant to rejected" do
      :ok = handle(%TenantRejected.V1{
        tenant_id: @tenant_id, rejected_by: "super", reason: nil,
        rejected_at: DateTime.utc_now()
      })
      assert Repo.get(TenantRead, @tenant_id).status == "rejected"
    end
  end

  describe "TenantConfigUpdated" do
    setup do
      :ok = handle(%TenantRegistered.V1{
        tenant_id: @tenant_id, slug: "acme", name: "Acme FC",
        registered_at: DateTime.utc_now()
      })
      :ok
    end

    test "merges config changes" do
      :ok = handle(%TenantConfigUpdated.V1{
        tenant_id: @tenant_id,
        changes: %{"rounds_to_win" => 3, "confirmation_mode" => "confirmation"},
        updated_by: "admin", updated_at: DateTime.utc_now()
      })

      config = Repo.get(TenantRead, @tenant_id).config
      assert config["rounds_to_win"] == 3
    end

    test "second update merges without overwriting unrelated keys" do
      :ok = handle(%TenantConfigUpdated.V1{
        tenant_id: @tenant_id, changes: %{"rounds_to_win" => 3},
        updated_by: "admin", updated_at: DateTime.utc_now()
      })
      :ok = handle(%TenantConfigUpdated.V1{
        tenant_id: @tenant_id, changes: %{"points_per_round" => 10},
        updated_by: "admin", updated_at: DateTime.utc_now()
      })

      config = Repo.get(TenantRead, @tenant_id).config
      assert config["rounds_to_win"] == 3
      assert config["points_per_round"] == 10
    end
  end

  describe "TenantDeletion lifecycle" do
    setup do
      :ok = handle(%TenantRegistered.V1{
        tenant_id: @tenant_id, slug: "acme", name: "Acme FC",
        registered_at: DateTime.utc_now()
      })
      :ok
    end

    test "TenantDeletionRequested sets status to deletion_pending" do
      :ok = handle(%TenantDeletionRequested.V1{
        tenant_id: @tenant_id, requested_by: "admin",
        grace_period_hours: 48,
        execute_at: DateTime.add(DateTime.utc_now(), 48 * 3600, :second),
        requested_at: DateTime.utc_now()
      })
      assert Repo.get(TenantRead, @tenant_id).status == "deletion_pending"
    end

    test "TenantDeletionConfirmed sets status to deleted" do
      :ok = handle(%TenantDeletionRequested.V1{
        tenant_id: @tenant_id, requested_by: "admin",
        grace_period_hours: 48,
        execute_at: DateTime.add(DateTime.utc_now(), 48 * 3600, :second),
        requested_at: DateTime.utc_now()
      })
      :ok = handle(%TenantDeletionConfirmed.V1{
        tenant_id: @tenant_id, confirmed_by: "super",
        confirmed_at: DateTime.utc_now()
      })
      assert Repo.get(TenantRead, @tenant_id).status == "deleted"
    end

    test "TenantDeletionCancelled restores status to active" do
      :ok = handle(%TenantDeletionRequested.V1{
        tenant_id: @tenant_id, requested_by: "admin",
        grace_period_hours: 48,
        execute_at: DateTime.add(DateTime.utc_now(), 48 * 3600, :second),
        requested_at: DateTime.utc_now()
      })
      :ok = handle(%TenantDeletionCancelled.V1{
        tenant_id: @tenant_id, cancelled_by: "admin",
        cancelled_at: DateTime.utc_now()
      })
      assert Repo.get(TenantRead, @tenant_id).status == "active"
    end
  end
end
