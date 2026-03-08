defmodule Zockelo.Domain.Commands.LogGame do
  @moduledoc """
  Log a completed game.

  `team1_players` and `team2_players` are lists of player UUIDs (1 or 2 each).
  `rounds` is a list of round maps (see `GameLogged.V1` for the round structure).
  `confirmation_mode`, `rounds_to_win`, and `points_per_round` are snapshotted
  from the current tenant config so projection replays are deterministic.
  """
  @enforce_keys [
    :game_id,
    :tenant_id,
    :logged_by,
    :team1_players,
    :team2_players,
    :rounds,
    :confirmation_mode,
    :rounds_to_win,
    :points_per_round
  ]
  defstruct [
    :game_id,
    :tenant_id,
    :logged_by,
    :team1_players,
    :team2_players,
    :rounds,
    :confirmation_mode,
    :rounds_to_win,
    :points_per_round
  ]
end

defmodule Zockelo.Domain.Commands.ConfirmGame do
  @moduledoc "Confirm a pending game (participant or tenant admin)."
  @enforce_keys [:game_id, :tenant_id, :confirmed_by]
  defstruct [:game_id, :tenant_id, :confirmed_by]
end

defmodule Zockelo.Domain.Commands.DisputeGame do
  @moduledoc "Dispute a pending game (participant or tenant admin)."
  @enforce_keys [:game_id, :tenant_id, :disputed_by]
  defstruct [:game_id, :tenant_id, :disputed_by, :reason]
end

defmodule Zockelo.Domain.Commands.ReinstateGame do
  @moduledoc "Reinstate a disputed game back to confirmed state (tenant admin only)."
  @enforce_keys [:game_id, :tenant_id, :reinstated_by]
  defstruct [:game_id, :tenant_id, :reinstated_by]
end

defmodule Zockelo.Domain.Commands.VoidGame do
  @moduledoc "Void a disputed game, removing it from ratings (tenant admin only)."
  @enforce_keys [:game_id, :tenant_id, :voided_by]
  defstruct [:game_id, :tenant_id, :voided_by]
end
