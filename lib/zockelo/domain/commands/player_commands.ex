defmodule Zockelo.Domain.Commands.InvitePlayer do
  @moduledoc """
  Invite a player to a tenant by email.

  `encrypted_email` must be pre-encrypted by the caller using the player's
  per-player key (see `Zockelo.Crypto`). The raw email is not stored in events.
  """
  @enforce_keys [:player_id, :tenant_id, :encrypted_email, :invited_by, :role]
  defstruct [:player_id, :tenant_id, :encrypted_email, :invited_by, :role]
end

defmodule Zockelo.Domain.Commands.ActivatePlayer do
  @moduledoc """
  Activate a player account after they click their magic link.

  `encrypted_name` must be pre-encrypted by the caller using the player's
  per-player key (see `Zockelo.Crypto`).
  """
  @enforce_keys [:player_id, :tenant_id, :encrypted_name]
  defstruct [:player_id, :tenant_id, :encrypted_name]
end

defmodule Zockelo.Domain.Commands.DeletePlayer do
  @moduledoc """
  Permanently delete a player.

  After this command is handled, the caller must delete the player's
  encryption key from `player_keys` and write a `gdpr_key_deletions` record.
  """
  @enforce_keys [:player_id, :tenant_id, :deleted_by]
  defstruct [:player_id, :tenant_id, :deleted_by]
end
