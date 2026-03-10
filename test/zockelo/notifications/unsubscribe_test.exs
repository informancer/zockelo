defmodule Zockelo.Notifications.UnsubscribeTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Notifications

  # Task 22.32 — HMAC unsubscribe tokens
  describe "unsubscribe_token/3" do
    @player_id Ecto.UUID.generate()
    @tenant_id Ecto.UUID.generate()
    @notif_type "game_confirmed"

    test "generates a non-empty token" do
      token = Notifications.unsubscribe_token(@player_id, @tenant_id, @notif_type)
      assert is_binary(token) and byte_size(token) > 0
    end

    test "valid token verifies successfully" do
      token = Notifications.unsubscribe_token(@player_id, @tenant_id, @notif_type)
      assert Notifications.verify_unsubscribe_token(token, @player_id, @tenant_id, @notif_type)
    end

    test "tampered token is rejected" do
      token = Notifications.unsubscribe_token(@player_id, @tenant_id, @notif_type)
      tampered = token <> "x"
      refute Notifications.verify_unsubscribe_token(tampered, @player_id, @tenant_id, @notif_type)
    end

    test "token for wrong player is rejected" do
      token = Notifications.unsubscribe_token(@player_id, @tenant_id, @notif_type)
      refute Notifications.verify_unsubscribe_token(token, Ecto.UUID.generate(), @tenant_id, @notif_type)
    end

    test "token for wrong type is rejected" do
      token = Notifications.unsubscribe_token(@player_id, @tenant_id, @notif_type)
      refute Notifications.verify_unsubscribe_token(token, @player_id, @tenant_id, "game_disputed")
    end
  end
end
