defmodule Zockelo.Domain.Events.GameLogged do
  @moduledoc """
  Emitted when a player submits a completed game.

  ## Round structure

  Each entry in `rounds` is a map with keys:
    - `team1_front`  — player_id of team 1 front player (nil for 1v1 or solo side in 2v1)
    - `team1_back`   — player_id of team 1 back player (nil for 1v1 or solo side in 2v1)
    - `team2_front`  — player_id of team 2 front player (nil for 1v1 or solo side in 2v1)
    - `team2_back`   — player_id of team 2 back player (nil for 1v1 or solo side in 2v1)
    - `team1_score`  — integer score for team 1 in this round
    - `team2_score`  — integer score for team 2 in this round

  Configuration is snapshotted at log time so that projection rebuilds produce
  consistent results even if tenant config changes later.
  """
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [
      :game_id,
      :tenant_id,
      :logged_by,
      :team1_players,
      :team2_players,
      :rounds,
      :confirmation_mode,
      :rounds_to_win,
      :points_per_round,
      :logged_at
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
      :points_per_round,
      :logged_at
    ]
  end
end

defmodule Zockelo.Domain.Events.GameConfirmed do
  @moduledoc "Emitted when a participant or tenant admin confirms a pending game."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:game_id, :tenant_id, :confirmed_by, :confirmed_at]
    defstruct [:game_id, :tenant_id, :confirmed_by, :confirmed_at]
  end
end

defmodule Zockelo.Domain.Events.GameDisputed do
  @moduledoc "Emitted when a participant or tenant admin disputes a pending game."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:game_id, :tenant_id, :disputed_by, :disputed_at]
    defstruct [:game_id, :tenant_id, :disputed_by, :reason, :disputed_at]
  end
end

defmodule Zockelo.Domain.Events.GameReinstated do
  @moduledoc "Emitted when a tenant admin reinstates a disputed game (moves it back to confirmed)."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:game_id, :tenant_id, :reinstated_by, :reinstated_at]
    defstruct [:game_id, :tenant_id, :reinstated_by, :reinstated_at]
  end
end

defmodule Zockelo.Domain.Events.GameVoided do
  @moduledoc "Emitted when a tenant admin voids a disputed game (removes it from ratings)."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:game_id, :tenant_id, :voided_by, :voided_at]
    defstruct [:game_id, :tenant_id, :voided_by, :voided_at]
  end
end
