defmodule Zockelo.Crypto.PlayerKeyHandler do
  @moduledoc """
  Commanded event handler that generates a per-player encryption key when a
  player is invited.

  This handler runs as part of the read-side pipeline. It is the authoritative
  point where player encryption keys are created — before any PII is written
  to the event stream, callers must first obtain the raw key via
  `Zockelo.Crypto.generate_player_key/2` and use it to pre-encrypt PII fields.

  This handler acts as a safety net: if the key does not yet exist when a
  `PlayerInvited` event is observed (e.g. during projection rebuild), it
  creates one. If the key already exists, it is a no-op.
  """

  use Commanded.Event.Handler,
    application: Zockelo.CommandedApp,
    name: __MODULE__

  alias Zockelo.Crypto
  alias Zockelo.Domain.Events.PlayerInvited

  def handle(%PlayerInvited.V1{player_id: player_id, tenant_id: tenant_id}, _metadata) do
    case Crypto.generate_player_key(player_id, tenant_id) do
      {:ok, _key} -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end
