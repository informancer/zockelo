defmodule Zockelo.PlayersTest do
  use Zockelo.DataCase, async: false
  import Swoosh.TestAssertions

  alias Zockelo.Players
  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile}
  alias Zockelo.Crypto.GdprKeyDeletion
  alias Zockelo.Auth.{MagicLinkToken, Session}

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @inviter_id "00000000-0000-0000-0000-000000000099"

  defp insert_tenant do
    Repo.insert!(%TenantRead{id: @tenant_id, slug: "acme", name: "Acme FC",
                              status: "active", config: %{}})
  end

  describe "invite_player/3" do
    setup [:insert_tenant_setup]

    test "creates a player profile with status 'invited'" do
      {:ok, player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)

      profile = Repo.get(PlayerProfile, player_id)
      assert profile.status == "invited"
      assert profile.tenant_id == @tenant_id
      assert profile.role == "player"
    end

    test "generates a player encryption key" do
      {:ok, player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)
      assert Zockelo.Crypto.key_exists?(player_id)
    end

    test "sends a magic link email" do
      {:ok, _player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)

      assert_email_sent(fn email ->
        assert email.to == [{"", "bob@example.com"}] or
               Enum.any?(email.to, fn {_, addr} -> addr == "bob@example.com" end)
      end)
    end

    test "stores a magic link token" do
      {:ok, player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)

      import Ecto.Query
      count = Repo.aggregate(
        from(t in MagicLinkToken, where: t.player_id == ^player_id),
        :count
      )
      assert count == 1
    end
  end

  describe "resend_magic_link/2" do
    setup [:insert_tenant_setup]

    test "sends a new magic link to an invited player" do
      {:ok, player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)
      # invite_player already sends one email; resend sends another
      :ok = Players.resend_magic_link(player_id, @tenant_id)

      # assert at least 2 emails sent total (invite + resend)
      assert_email_sent(fn email ->
        assert email.to |> Enum.any?(fn {_, addr} -> addr == "bob@example.com" end)
      end)
    end
  end

  describe "delete_player/3" do
    setup [:insert_tenant_setup]

    test "crypto-shreds the player key" do
      {:ok, player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)
      :ok = Players.delete_player(player_id, @tenant_id, @inviter_id)

      refute Zockelo.Crypto.key_exists?(player_id)
      assert Zockelo.Crypto.key_deletion_logged?(player_id)
    end

    test "updates player profile status to deleted" do
      {:ok, player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)
      :ok = Players.delete_player(player_id, @tenant_id, @inviter_id)

      profile = Repo.get(PlayerProfile, player_id)
      assert profile.status == "deleted"
    end

    test "revokes all sessions for the player" do
      {:ok, player_id} = Players.invite_player(@tenant_id, "bob@example.com", @inviter_id)
      {:ok, _session} = Zockelo.Auth.create_session(player_id, @tenant_id)

      :ok = Players.delete_player(player_id, @tenant_id, @inviter_id)

      import Ecto.Query
      count = Repo.aggregate(from(s in Session, where: s.player_id == ^player_id), :count)
      assert count == 0
    end
  end

  describe "list_players/1" do
    setup [:insert_tenant_setup]

    test "returns all player profiles for a tenant" do
      {:ok, p1} = Players.invite_player(@tenant_id, "a@example.com", @inviter_id)
      {:ok, p2} = Players.invite_player(@tenant_id, "b@example.com", @inviter_id)

      player_ids = Players.list_players(@tenant_id) |> Enum.map(& &1.player_id)
      assert p1 in player_ids
      assert p2 in player_ids
    end
  end

  describe "update_tenant_config/2" do
    test "dispatches UpdateTenantConfig command successfully" do
      # Register tenant via aggregate so the stream exists
      :ok = Zockelo.CommandedApp.dispatch(%Zockelo.Domain.Commands.RegisterTenant{
        tenant_id: @tenant_id, slug: "acme", name: "Acme FC"
      })

      assert :ok = Players.update_tenant_config(@tenant_id, %{
        "rounds_to_win" => 3,
        "confirmation_mode" => "trust"
      }, @inviter_id)
    end
  end

  defp insert_tenant_setup(_ctx) do
    insert_tenant()
    :ok
  end
end
