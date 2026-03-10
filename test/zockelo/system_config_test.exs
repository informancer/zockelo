defmodule Zockelo.SystemConfigTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.SystemConfig

  describe "get/1" do
    test "returns default for tenant_creation_mode" do
      assert SystemConfig.get("tenant_creation_mode") == "direct"
    end

    test "returns default for audit_log_retention_days" do
      assert SystemConfig.get("audit_log_retention_days") == "730"
    end

    test "returns empty string default for maintenance_message" do
      assert SystemConfig.get("maintenance_message") == ""
    end

    test "returns stored value when set" do
      SystemConfig.put("maintenance_message", "Downtime tonight at 23:00")
      assert SystemConfig.get("maintenance_message") == "Downtime tonight at 23:00"
    end

    test "clearing maintenance_message ends maintenance mode" do
      SystemConfig.put("maintenance_message", "Some message")
      SystemConfig.put("maintenance_message", "")
      assert SystemConfig.get("maintenance_message") == ""
    end
  end

  # Task 22.59 — audit log retention minimum enforcement
  describe "audit_log_retention_days minimum" do
    test "default is 730 days" do
      val = SystemConfig.get("audit_log_retention_days") |> String.to_integer()
      assert val >= 90
    end
  end
end
