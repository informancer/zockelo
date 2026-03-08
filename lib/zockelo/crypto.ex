defmodule Zockelo.Crypto do
  @moduledoc """
  Crypto-shredding context.

  Each player has a unique AES key stored (envelope-encrypted via Cloak.Vault)
  in the `player_keys` table. PII fields in events are encrypted with that key.
  On player deletion, the key is deleted and a GDPR audit record is written —
  making all encrypted PII permanently unreadable without mutating the event log.
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Crypto.{PlayerKey, GdprKeyDeletion}

  @deleted_player_name "[Deleted Player]"

  # ---------------------------------------------------------------------------
  # Key lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Generates a fresh AES-256 key for `player_id`, encrypts it with the Cloak
  vault (master key), and stores the ciphertext in `player_keys`.

  Returns `{:ok, raw_key}` so the caller can immediately use it for
  encrypting the player's invite email before dispatching the command.
  Returns `{:error, :already_exists}` if a key already exists for this player.
  """
  def generate_player_key(player_id, tenant_id) do
    if key_exists?(player_id) do
      {:error, :already_exists}
    else
      raw_key = :crypto.strong_rand_bytes(32)
      {:ok, encrypted_key} = Zockelo.Vault.encrypt(raw_key)

      attrs = %{
        player_id: player_id,
        tenant_id: tenant_id,
        encrypted_key: encrypted_key,
        created_at: DateTime.utc_now()
      }

      case Repo.insert(PlayerKey.changeset(attrs)) do
        {:ok, _row} -> {:ok, raw_key}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  Encrypts `plaintext` using the player's stored key.

  Returns `{:ok, ciphertext}` on success, `{:error, :key_deleted}` if the
  player's key no longer exists.
  """
  def encrypt_field(player_id, plaintext) do
    with {:ok, raw_key} <- fetch_raw_key(player_id) do
      encrypted = encrypt_with_key(raw_key, plaintext)
      {:ok, encrypted}
    end
  end

  @doc """
  Decrypts `ciphertext` using the player's stored key.

  Returns `{:ok, plaintext}` on success, `{:error, :key_deleted}` if the
  player's key has been deleted (crypto-shredded).
  """
  def decrypt_field(player_id, ciphertext) do
    with {:ok, raw_key} <- fetch_raw_key(player_id) do
      {:ok, decrypt_with_key(raw_key, ciphertext)}
    end
  end

  @doc """
  Deletes the player's encryption key and records the deletion in the GDPR
  audit log. Idempotent — safe to call even if the key is already gone.
  """
  def delete_player_key(player_id, tenant_id) do
    Repo.transaction(fn ->
      Repo.delete_all(from pk in PlayerKey, where: pk.player_id == ^player_id)

      attrs = %{player_id: player_id, tenant_id: tenant_id, deleted_at: DateTime.utc_now()}

      case Repo.get(GdprKeyDeletion, player_id) do
        nil -> Repo.insert!(GdprKeyDeletion.changeset(attrs))
        _existing -> :already_logged
      end
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers (also used in tests)
  # ---------------------------------------------------------------------------

  @doc "Returns true if an encryption key exists for the player."
  def key_exists?(player_id) do
    Repo.exists?(from pk in PlayerKey, where: pk.player_id == ^player_id)
  end

  @doc "Returns true if a GDPR key deletion has been logged for the player."
  def key_deletion_logged?(player_id) do
    Repo.exists?(from d in GdprKeyDeletion, where: d.player_id == ^player_id)
  end

  @doc "The display string used when a player's PII cannot be decrypted."
  def deleted_player_name, do: @deleted_player_name

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp fetch_raw_key(player_id) do
    case Repo.get(PlayerKey, player_id) do
      nil -> {:error, :key_deleted}
      %PlayerKey{encrypted_key: enc} -> Zockelo.Vault.decrypt(enc)
    end
  end

  # AES-256-GCM with a random nonce prepended to the ciphertext.
  # Format: <<nonce::binary-12, tag::binary-16, ciphertext::binary>>
  defp encrypt_with_key(key, plaintext) do
    nonce = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, "", true)
    nonce <> tag <> ciphertext
  end

  defp decrypt_with_key(key, <<nonce::binary-12, tag::binary-16, ciphertext::binary>>) do
    :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, "", tag, false)
  end
end
