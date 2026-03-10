defmodule Zockelo.NotificationPreferencesTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Notifications

  # Task 22.37 — Oban unique constraint
  describe "notification types" do
    test "maintenance_announcements is a player type" do
      assert "maintenance_announcements" in Notifications.player_types()
    end

    test "all_configurable_types includes player and admin types" do
      types = Notifications.all_configurable_types()
      assert "game_logged" in types
      assert "game_disputed_admin" in types
    end
  end

  # Task 22.53 — Oban queue assignment
  describe "worker queue assignments" do
    test "MaintenanceBroadcastWorker is in notifications queue" do
      assert Zockelo.Workers.MaintenanceBroadcastWorker.__opts__()[:queue] == :notifications
    end

    test "InactiveAccountWarningWorker is in scheduled queue" do
      assert Zockelo.Workers.InactiveAccountWarningWorker.__opts__()[:queue] == :scheduled
    end

    test "InactiveAccountDeletionWorker is in scheduled queue" do
      assert Zockelo.Workers.InactiveAccountDeletionWorker.__opts__()[:queue] == :scheduled
    end

    test "StaleRecordCleanupWorker is in scheduled queue" do
      assert Zockelo.Workers.StaleRecordCleanupWorker.__opts__()[:queue] == :scheduled
    end

    test "GameNotificationWorker is in notifications queue" do
      assert Zockelo.Workers.GameNotificationWorker.__opts__()[:queue] == :notifications
    end
  end
end
