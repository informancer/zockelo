defmodule Zockelo.Domain.Events.PlayerInvited do
  @moduledoc """
  Emitted when a tenant admin invites a player by email or when a player
  self-registers via invite link.

  PII fields (encrypted_email) are AES-encrypted with the player's per-player
  key (stored in `player_keys`). On player deletion, the key is deleted and
  the email becomes unreadable — crypto-shredding.
  """
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:player_id, :tenant_id, :encrypted_email, :invited_by, :role, :invited_at]
    defstruct [:player_id, :tenant_id, :encrypted_email, :invited_by, :role, :invited_at]
  end
end

defmodule Zockelo.Domain.Events.PlayerActivated do
  @moduledoc """
  Emitted when a player clicks their magic link and completes registration.

  `encrypted_name` is AES-encrypted with the player's per-player key.
  """
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:player_id, :tenant_id, :encrypted_name, :activated_at]
    defstruct [:player_id, :tenant_id, :encrypted_name, :activated_at]
  end
end

defmodule Zockelo.Domain.Events.PlayerDeleted do
  @moduledoc """
  Emitted when a tenant admin permanently deletes a player.

  After this event, the player's encryption key is deleted from `player_keys`
  and a `gdpr_key_deletions` entry is recorded. The player's name and email
  in historical events become unreadable; they are displayed as "[Deleted Player]".
  """
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:player_id, :tenant_id, :deleted_by, :deleted_at]
    defstruct [:player_id, :tenant_id, :deleted_by, :deleted_at]
  end
end
