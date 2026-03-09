defmodule Zockelo.Auth.InviteLinkTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Auth
  alias Zockelo.Auth.InviteLink

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @admin_id  "00000000-0000-0000-0000-000000000010"

  describe "generate_invite_link/3" do
    test "creates an invite link and returns {:ok, token}" do
      assert {:ok, token} = Auth.generate_invite_link(@tenant_id, @admin_id, [])
      assert is_binary(token)
      assert Repo.aggregate(InviteLink, :count) == 1
    end

    test "generates a unique token each call" do
      {:ok, t1} = Auth.generate_invite_link(@tenant_id, @admin_id, [])
      {:ok, t2} = Auth.generate_invite_link(@tenant_id, @admin_id, [])
      assert t1 != t2
    end

    test "respects an optional expires_at" do
      expires = DateTime.add(DateTime.utc_now(), 3600, :second)
      {:ok, token} = Auth.generate_invite_link(@tenant_id, @admin_id, expires_at: expires)

      link = Repo.get_by!(InviteLink, token: token)
      assert link.expires_at != nil
    end
  end

  describe "validate_invite_link/2" do
    test "valid link returns {:ok, tenant_id}" do
      {:ok, token} = Auth.generate_invite_link(@tenant_id, @admin_id, [])

      assert {:ok, @tenant_id} = Auth.validate_invite_link(token, @tenant_id)
    end

    test "unknown token returns {:error, :not_found}" do
      assert {:error, :not_found} = Auth.validate_invite_link("bad-token", @tenant_id)
    end

    test "expired link returns {:error, :expired}" do
      {:ok, token} = Auth.generate_invite_link(@tenant_id, @admin_id,
        expires_at: DateTime.add(DateTime.utc_now(), -1, :second))

      assert {:error, :expired} = Auth.validate_invite_link(token, @tenant_id)
    end

    test "revoked link returns {:error, :revoked}" do
      {:ok, token} = Auth.generate_invite_link(@tenant_id, @admin_id, [])

      Repo.update_all(InviteLink,
        set: [revoked_at: DateTime.utc_now()])

      assert {:error, :revoked} = Auth.validate_invite_link(token, @tenant_id)
    end

    test "link for wrong tenant returns {:error, :not_found}" do
      {:ok, token} = Auth.generate_invite_link(@tenant_id, @admin_id, [])
      other_tenant = "00000000-0000-0000-0000-000000000002"

      assert {:error, :not_found} = Auth.validate_invite_link(token, other_tenant)
    end
  end

  describe "rotate_invite_link/3" do
    test "revokes the old token and creates a new one" do
      {:ok, old_token} = Auth.generate_invite_link(@tenant_id, @admin_id, [])

      {:ok, new_token} = Auth.rotate_invite_link(@tenant_id, old_token, @admin_id)

      assert new_token != old_token

      old_link = Repo.get_by!(InviteLink, token: old_token)
      assert old_link.revoked_at != nil

      assert {:ok, @tenant_id} = Auth.validate_invite_link(new_token, @tenant_id)
    end

    test "returns {:error, :not_found} if old token doesn't exist" do
      assert {:error, :not_found} = Auth.rotate_invite_link(@tenant_id, "bad-token", @admin_id)
    end
  end
end
