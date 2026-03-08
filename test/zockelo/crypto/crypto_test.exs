defmodule Zockelo.CryptoTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Crypto

  @player_id "00000000-0000-0000-0000-000000000010"
  @tenant_id "00000000-0000-0000-0000-000000000001"
  @plaintext "alice@example.com"

  # ---------------------------------------------------------------------------
  # generate_player_key/2
  # ---------------------------------------------------------------------------

  describe "generate_player_key/2" do
    test "creates a player_keys row" do
      assert {:ok, _key} = Crypto.generate_player_key(@player_id, @tenant_id)
      assert Crypto.key_exists?(@player_id)
    end

    test "returns error if key already exists" do
      {:ok, _} = Crypto.generate_player_key(@player_id, @tenant_id)
      assert {:error, :already_exists} = Crypto.generate_player_key(@player_id, @tenant_id)
    end
  end

  # ---------------------------------------------------------------------------
  # encrypt_field/2 + decrypt_field/2
  # ---------------------------------------------------------------------------

  describe "encrypt_field/2 and decrypt_field/2 round-trip" do
    setup do
      {:ok, _} = Crypto.generate_player_key(@player_id, @tenant_id)
      :ok
    end

    test "encrypts a plaintext value" do
      {:ok, ciphertext} = Crypto.encrypt_field(@player_id, @plaintext)
      assert is_binary(ciphertext)
      refute ciphertext == @plaintext
    end

    test "decrypts back to the original value" do
      {:ok, ciphertext} = Crypto.encrypt_field(@player_id, @plaintext)
      assert {:ok, @plaintext} = Crypto.decrypt_field(@player_id, ciphertext)
    end

    test "different encryptions of the same value produce different ciphertext (nonce)" do
      {:ok, c1} = Crypto.encrypt_field(@player_id, @plaintext)
      {:ok, c2} = Crypto.encrypt_field(@player_id, @plaintext)
      # AES-GCM uses a random nonce, so ciphertexts differ
      assert c1 != c2
    end
  end

  # ---------------------------------------------------------------------------
  # decrypt_field/2 — deleted key (crypto-shredding)
  # ---------------------------------------------------------------------------

  describe "decrypt_field/2 after key deletion" do
    test "returns {:error, :key_deleted} when key is gone" do
      {:ok, _} = Crypto.generate_player_key(@player_id, @tenant_id)
      {:ok, ciphertext} = Crypto.encrypt_field(@player_id, @plaintext)

      :ok = Crypto.delete_player_key(@player_id, @tenant_id)

      assert {:error, :key_deleted} = Crypto.decrypt_field(@player_id, ciphertext)
    end

    test "decrypt_field/2 returns [Deleted Player] helper string via helper" do
      assert Crypto.deleted_player_name() == "[Deleted Player]"
    end
  end

  # ---------------------------------------------------------------------------
  # delete_player_key/2
  # ---------------------------------------------------------------------------

  describe "delete_player_key/2" do
    test "removes the key row and inserts a gdpr_key_deletions record" do
      {:ok, _} = Crypto.generate_player_key(@player_id, @tenant_id)
      assert Crypto.key_exists?(@player_id)

      :ok = Crypto.delete_player_key(@player_id, @tenant_id)

      refute Crypto.key_exists?(@player_id)
      assert Crypto.key_deletion_logged?(@player_id)
    end

    test "is idempotent — no error if key already gone" do
      {:ok, _} = Crypto.generate_player_key(@player_id, @tenant_id)
      :ok = Crypto.delete_player_key(@player_id, @tenant_id)
      assert :ok = Crypto.delete_player_key(@player_id, @tenant_id)
    end
  end
end
