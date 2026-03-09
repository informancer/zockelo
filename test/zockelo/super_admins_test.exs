defmodule Zockelo.SuperAdminsTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.SuperAdmins
  alias Zockelo.SuperAdmins.SuperAdmin
  alias Zockelo.Repo

  @email "admin@example.com"
  @player_id "00000000-0000-0000-0000-000000000099"

  describe "create_super_admin/1" do
    test "creates a super admin with encrypted email" do
      assert {:ok, sa} = SuperAdmins.create_super_admin(@player_id, @email)
      assert sa.player_id == @player_id
      assert Repo.get(SuperAdmin, @player_id)
    end

    test "decrypting the stored email returns the original" do
      {:ok, sa} = SuperAdmins.create_super_admin(@player_id, @email)
      assert {:ok, @email} = SuperAdmins.decrypt_email(sa)
    end

    test "is idempotent — returns :already_exists if super admin exists" do
      {:ok, _} = SuperAdmins.create_super_admin(@player_id, @email)
      assert {:error, :already_exists} = SuperAdmins.create_super_admin(@player_id, @email)
    end

    test "stores distinct records for different player IDs" do
      other_player_id = "00000000-0000-0000-0000-000000000098"
      {:ok, _} = SuperAdmins.create_super_admin(@player_id, @email)
      {:ok, _} = SuperAdmins.create_super_admin(other_player_id, "other@example.com")
      assert Repo.aggregate(SuperAdmin, :count) == 2
    end
  end

  describe "list_super_admins/0" do
    test "returns all super admins" do
      {:ok, _} = SuperAdmins.create_super_admin(@player_id, @email)
      assert [sa] = SuperAdmins.list_super_admins()
      assert sa.player_id == @player_id
    end

    test "returns empty list when none exist" do
      assert [] = SuperAdmins.list_super_admins()
    end
  end

  describe "super_admin?/1" do
    test "returns true if player is a super admin" do
      {:ok, _} = SuperAdmins.create_super_admin(@player_id, @email)
      assert SuperAdmins.super_admin?(@player_id)
    end

    test "returns false if player is not a super admin" do
      refute SuperAdmins.super_admin?(@player_id)
    end
  end

  describe "remove_super_admin/1" do
    test "removes the super admin record" do
      {:ok, _} = SuperAdmins.create_super_admin(@player_id, @email)
      :ok = SuperAdmins.remove_super_admin(@player_id)
      refute Repo.get(SuperAdmin, @player_id)
    end

    test "returns :error when not found" do
      assert {:error, :not_found} = SuperAdmins.remove_super_admin(@player_id)
    end
  end
end
