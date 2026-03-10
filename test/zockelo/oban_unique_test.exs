defmodule Zockelo.ObanUniqueTest do
  use Zockelo.DataCase, async: false

  # Task 22.37 — Oban unique job constraint
  describe "notification job uniqueness" do
    test "GameNotificationWorker declares unique constraint on trigger_id" do
      opts = Zockelo.Workers.GameNotificationWorker.__opts__()
      assert Keyword.has_key?(opts, :unique)

      unique = Keyword.fetch!(opts, :unique)
      # Unique constraint should key on trigger_id (or similar dedup field)
      keys = unique[:keys] || []
      fields = unique[:fields] || []
      assert "trigger_id" in Enum.map(keys, &to_string/1) or
             :trigger_id in keys or
             "trigger_id" in Enum.map(fields, &to_string/1)
    end

    test "GameNotificationWorker has a unique period set" do
      opts = Zockelo.Workers.GameNotificationWorker.__opts__()
      unique = Keyword.fetch!(opts, :unique)
      period = unique[:period]
      assert is_integer(period) and period > 0
    end
  end
end
