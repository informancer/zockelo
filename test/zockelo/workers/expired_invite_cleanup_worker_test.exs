defmodule Zockelo.Workers.ExpiredInviteCleanupWorkerTest do
  use Zockelo.DataCase, async: false
  use Oban.Testing, repo: Zockelo.Repo

  alias Zockelo.Workers.ExpiredInviteCleanupWorker
  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile}

  @tenant_id "00000000-0000-0000-0000-000000000001"

  defp insert_tenant do
    Repo.insert!(%TenantRead{id: @tenant_id, slug: "acme", name: "Acme", status: "active", config: %{}})
  end

  defp insert_invited_player(player_id, invited_at \\ DateTime.utc_now()) do
    Repo.insert!(%PlayerProfile{
      player_id: player_id,
      tenant_id: @tenant_id,
      role: "player",
      status: "invited",
      inserted_at: invited_at,
      updated_at: invited_at
    })
  end

  describe "perform/1" do
    setup do
      insert_tenant()
      :ok
    end

    test "deletes invited players past the retention window" do
      old_player_id = "00000000-0000-0000-0000-000000000010"
      old_invited_at = DateTime.add(DateTime.utc_now(), -(31 * 24 * 3600), :second)
      insert_invited_player(old_player_id, old_invited_at)

      assert :ok = perform_job(ExpiredInviteCleanupWorker, %{"tenant_id" => @tenant_id})

      assert Repo.get(PlayerProfile, old_player_id) == nil
    end

    test "keeps recently invited players" do
      new_player_id = "00000000-0000-0000-0000-000000000011"
      insert_invited_player(new_player_id)

      assert :ok = perform_job(ExpiredInviteCleanupWorker, %{"tenant_id" => @tenant_id})

      assert Repo.get(PlayerProfile, new_player_id) != nil
    end

    test "keeps active players regardless of age" do
      active_player_id = "00000000-0000-0000-0000-000000000012"
      old_inserted_at = DateTime.add(DateTime.utc_now(), -(31 * 24 * 3600), :second)

      Repo.insert!(%PlayerProfile{
        player_id: active_player_id,
        tenant_id: @tenant_id,
        role: "player",
        status: "active",
        inserted_at: old_inserted_at,
        updated_at: old_inserted_at
      })

      assert :ok = perform_job(ExpiredInviteCleanupWorker, %{"tenant_id" => @tenant_id})

      assert Repo.get(PlayerProfile, active_player_id) != nil
    end
  end
end
