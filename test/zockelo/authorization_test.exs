defmodule Zockelo.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Zockelo.Authorization
  alias Zockelo.Projections.PlayerProfile

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @other_tenant "00000000-0000-0000-0000-000000000002"

  defp player(role \\ "player", tenant_id \\ @tenant_id) do
    %PlayerProfile{
      player_id: "00000000-0000-0000-0000-000000000010",
      tenant_id: tenant_id,
      role: role,
      status: "active"
    }
  end

  describe "authorize/3 — nil user" do
    test "any action returns {:error, :unauthenticated}" do
      assert {:error, :unauthenticated} = Authorization.authorize(nil, :view, @tenant_id)
      assert {:error, :unauthenticated} = Authorization.authorize(nil, :admin, @tenant_id)
    end
  end

  describe "authorize/3 — super_admin" do
    test "can do anything in any tenant" do
      user = player("super_admin", @tenant_id)
      assert :ok = Authorization.authorize(user, :view, @tenant_id)
      assert :ok = Authorization.authorize(user, :admin, @tenant_id)
      assert :ok = Authorization.authorize(user, :admin, @other_tenant)
      assert :ok = Authorization.authorize(user, :super_admin, nil)
    end
  end

  describe "authorize/3 — tenant_admin" do
    test "can do :admin in their own tenant" do
      user = player("tenant_admin", @tenant_id)
      assert :ok = Authorization.authorize(user, :admin, @tenant_id)
    end

    test "cannot do :admin in another tenant" do
      user = player("tenant_admin", @tenant_id)
      assert {:error, :forbidden} = Authorization.authorize(user, :admin, @other_tenant)
    end

    test "can do :view in their tenant" do
      user = player("tenant_admin", @tenant_id)
      assert :ok = Authorization.authorize(user, :view, @tenant_id)
    end

    test "cannot do :super_admin" do
      user = player("tenant_admin", @tenant_id)
      assert {:error, :forbidden} = Authorization.authorize(user, :super_admin, nil)
    end
  end

  describe "authorize/3 — player" do
    test "can do :view in their tenant" do
      user = player("player", @tenant_id)
      assert :ok = Authorization.authorize(user, :view, @tenant_id)
    end

    test "cannot do :admin" do
      user = player("player", @tenant_id)
      assert {:error, :forbidden} = Authorization.authorize(user, :admin, @tenant_id)
    end

    test "cannot do :super_admin" do
      user = player("player", @tenant_id)
      assert {:error, :forbidden} = Authorization.authorize(user, :super_admin, nil)
    end
  end
end
