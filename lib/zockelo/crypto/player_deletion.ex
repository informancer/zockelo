defmodule Zockelo.Crypto.PlayerDeletion do
  @moduledoc """
  Executes the crypto-shredding side of player deletion.

  Called by the PlayerDeleted event handler after the aggregate emits the event.
  Responsibilities:
    1. Delete the player's encryption key (crypto-shredding)
    2. Write a GDPR key deletion audit record
    3. Revoke active sessions       — stub until sessions table exists (section 5)
    4. Delete magic link tokens     — stub until tokens table exists (section 5)
  """

  alias Zockelo.Crypto

  @doc """
  Executes all crypto-shredding steps for the given player. Idempotent.
  """
  def execute(player_id, tenant_id) do
    :ok = Crypto.delete_player_key(player_id, tenant_id)
    :ok = revoke_sessions(player_id)
    :ok = delete_magic_link_tokens(player_id)
    :ok
  end

  # Stubs — implemented in section 5 (Authentication)
  defp revoke_sessions(_player_id), do: :ok
  defp delete_magic_link_tokens(_player_id), do: :ok
end
