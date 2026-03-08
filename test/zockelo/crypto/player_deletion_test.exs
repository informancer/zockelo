defmodule Zockelo.Crypto.PlayerDeletionTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Crypto
  alias Zockelo.Crypto.PlayerDeletion

  @player_id "00000000-0000-0000-0000-000000000010"
  @tenant_id "00000000-0000-0000-0000-000000000001"

  setup do
    {:ok, _} = Crypto.generate_player_key(@player_id, @tenant_id)
    :ok
  end

  describe "execute/2" do
    test "deletes the player's encryption key" do
      assert Crypto.key_exists?(@player_id)
      :ok = PlayerDeletion.execute(@player_id, @tenant_id)
      refute Crypto.key_exists?(@player_id)
    end

    test "writes a GDPR audit record" do
      :ok = PlayerDeletion.execute(@player_id, @tenant_id)
      assert Crypto.key_deletion_logged?(@player_id)
    end

    test "is idempotent" do
      :ok = PlayerDeletion.execute(@player_id, @tenant_id)
      assert :ok = PlayerDeletion.execute(@player_id, @tenant_id)
    end
  end
end
