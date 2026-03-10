defmodule Zockelo.ReleaseTasksTest do
  use Zockelo.DataCase, async: false

  alias Zockelo.ReleaseTasks

  # Task 22.54
  describe "create_super_admin/1" do
    test "creates a super admin on first call" do
      email = "superadmin_#{System.unique_integer()}@test.example"
      assert {:ok, sa} = ReleaseTasks.create_super_admin(email)
      assert is_binary(sa.player_id)
    end

    test "returns :already_exists and no-ops on second call with same email" do
      email = "superadmin_dup_#{System.unique_integer()}@test.example"
      {:ok, _} = ReleaseTasks.create_super_admin(email)
      assert :already_exists = ReleaseTasks.create_super_admin(email)
    end
  end
end
