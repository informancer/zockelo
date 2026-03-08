defmodule Zockelo.Crypto.PlayerKeyHandlerTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Crypto
  alias Zockelo.Crypto.PlayerKeyHandler
  alias Zockelo.Domain.Events.PlayerInvited

  @player_id "00000000-0000-0000-0000-000000000010"
  @tenant_id "00000000-0000-0000-0000-000000000001"

  describe "handle PlayerInvited.V1" do
    test "generates and stores a key for the new player" do
      event = %PlayerInvited.V1{
        player_id: @player_id,
        tenant_id: @tenant_id,
        encrypted_email: "ignored-for-key-gen",
        invited_by: "admin",
        role: :player,
        invited_at: DateTime.utc_now()
      }

      :ok = PlayerKeyHandler.handle(event, %{})

      assert Crypto.key_exists?(@player_id)
    end

    test "is idempotent — handles duplicate PlayerInvited without error" do
      event = %PlayerInvited.V1{
        player_id: @player_id,
        tenant_id: @tenant_id,
        encrypted_email: "ignored",
        invited_by: "admin",
        role: :player,
        invited_at: DateTime.utc_now()
      }

      :ok = PlayerKeyHandler.handle(event, %{})
      :ok = PlayerKeyHandler.handle(event, %{})

      assert Crypto.key_exists?(@player_id)
    end
  end
end
