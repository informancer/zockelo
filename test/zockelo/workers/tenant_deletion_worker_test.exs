defmodule Zockelo.Workers.TenantDeletionWorkerTest do
  use Zockelo.DataCase, async: false
  use Oban.Testing, repo: Zockelo.Repo

  alias Zockelo.Workers.TenantDeletionWorker
  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile, PlayerRating}
  alias Zockelo.Crypto.{PlayerKey, GdprKeyDeletion}

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @p1 "00000000-0000-0000-0000-000000000010"
  @p2 "00000000-0000-0000-0000-000000000011"

  defp insert_tenant(status \\ "deletion_pending") do
    Repo.insert!(%TenantRead{id: @tenant_id, slug: "acme", name: "Acme", status: status, config: %{}})
  end

  defp insert_player(player_id) do
    Repo.insert!(%PlayerProfile{
      player_id: player_id, tenant_id: @tenant_id,
      role: "player", status: "active"
    })
    {:ok, raw_key} = Zockelo.Crypto.generate_player_key(player_id, @tenant_id)
    raw_key
  end

  describe "perform/1 — happy path" do
    test "crypto-shreds all players in the tenant" do
      insert_tenant()
      insert_player(@p1)
      insert_player(@p2)

      assert :ok = perform_job(TenantDeletionWorker, %{"tenant_id" => @tenant_id})

      # Keys must be deleted
      refute Repo.get(PlayerKey, @p1)
      refute Repo.get(PlayerKey, @p2)

      # GDPR records must exist
      assert Repo.get(GdprKeyDeletion, @p1)
      assert Repo.get(GdprKeyDeletion, @p2)
    end

    test "marks tenant as deleted in projection" do
      insert_tenant()

      assert :ok = perform_job(TenantDeletionWorker, %{"tenant_id" => @tenant_id})

      assert Repo.get(TenantRead, @tenant_id).status == "deleted"
    end

    test "does nothing (no error) when tenant is already deleted" do
      insert_tenant("deleted")

      assert :ok = perform_job(TenantDeletionWorker, %{"tenant_id" => @tenant_id})
    end
  end

  describe "perform/1 — missing tenant" do
    test "returns ok when tenant not found (idempotent)" do
      assert :ok = perform_job(TenantDeletionWorker, %{"tenant_id" => @tenant_id})
    end
  end
end
