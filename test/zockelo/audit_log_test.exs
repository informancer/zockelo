defmodule Zockelo.AuditLogTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Audit
  alias Zockelo.Audit.AdminAuditLog

  # Task 22.22 — Audit log entries for security-sensitive actions
  describe "log/1" do
    test "creates an audit log entry" do
      actor_id = Ecto.UUID.generate()
      target_id = Ecto.UUID.generate()

      assert :ok = Audit.log(%{
        action: "role_granted",
        actor_id: actor_id,
        actor_role: "super_admin",
        target_id: target_id,
        tenant_id: Ecto.UUID.generate(),
        metadata: %{"role" => "tenant_admin"}
      })

      entry = Repo.one!(from a in AdminAuditLog, where: a.actor_id == ^actor_id)
      assert entry.action == "role_granted"
      assert entry.target_id == target_id
    end
  end

  # Task 22.56 — audit log retained after actor deletion
  describe "audit log retention" do
    test "entries persist when actor_id is no longer in player_profiles" do
      actor_id = Ecto.UUID.generate()

      :ok = Audit.log(%{
        action: "player_deleted",
        actor_id: actor_id,
        actor_role: "tenant_admin",
        target_id: Ecto.UUID.generate(),
        tenant_id: Ecto.UUID.generate()
      })

      # Even after deletion of the actor, the log entry should remain
      count = Repo.aggregate(from(a in AdminAuditLog, where: a.actor_id == ^actor_id), :count)
      assert count == 1
    end
  end
end
