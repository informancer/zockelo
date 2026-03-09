defmodule Zockelo.Domain.Aggregates.Game do
  @moduledoc """
  Game aggregate. Manages the lifecycle of a logged game.

  State transitions:
    nil → :pending   (LogGame, confirmation mode)
    nil → :confirmed (LogGame, trust mode — immediate confirmation)
    :pending → :confirmed (ConfirmGame)
    :pending → :disputed  (DisputeGame)
    :disputed → :confirmed (ReinstateGame)
    :disputed → :voided    (VoidGame)

  Validation:
  - No player may appear more than once across team1 and team2
  - Scores must not exceed points_per_round
  - One team must reach rounds_to_win wins
  """

  alias Zockelo.Domain.Commands.{LogGame, ConfirmGame, DisputeGame, ReinstateGame, VoidGame}

  alias Zockelo.Domain.Events.{
    GameLogged,
    GameConfirmed,
    GameDisputed,
    GameReinstated,
    GameVoided
  }

  defstruct [
    :game_id,
    :tenant_id,
    :team1_players,
    :team2_players,
    :confirmation_mode,
    :status
  ]

  # ---------------------------------------------------------------------------
  # Command handlers
  # ---------------------------------------------------------------------------

  def execute(%__MODULE__{status: nil}, %LogGame{} = cmd) do
    with :ok <- validate_players(cmd),
         :ok <- validate_scores(cmd),
         :ok <- validate_winning_condition(cmd) do
      initial_status = if cmd.confirmation_mode == :trust, do: :confirmed, else: :pending

      event = %GameLogged.V1{
        game_id: cmd.game_id,
        tenant_id: cmd.tenant_id,
        logged_by: cmd.logged_by,
        team1_players: cmd.team1_players,
        team2_players: cmd.team2_players,
        rounds: cmd.rounds,
        confirmation_mode: cmd.confirmation_mode,
        rounds_to_win: cmd.rounds_to_win,
        points_per_round: cmd.points_per_round,
        logged_at: DateTime.utc_now()
      }

      if initial_status == :confirmed do
        [event, %GameConfirmed.V1{
          game_id: cmd.game_id,
          tenant_id: cmd.tenant_id,
          confirmed_by: cmd.logged_by,
          confirmed_at: DateTime.utc_now()
        }]
      else
        event
      end
    end
  end

  def execute(%__MODULE__{status: :pending}, %ConfirmGame{} = cmd) do
    %GameConfirmed.V1{
      game_id: cmd.game_id,
      tenant_id: cmd.tenant_id,
      confirmed_by: cmd.confirmed_by,
      confirmed_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :pending}, %DisputeGame{} = cmd) do
    %GameDisputed.V1{
      game_id: cmd.game_id,
      tenant_id: cmd.tenant_id,
      disputed_by: cmd.disputed_by,
      reason: cmd.reason,
      disputed_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :disputed}, %ReinstateGame{} = cmd) do
    %GameReinstated.V1{
      game_id: cmd.game_id,
      tenant_id: cmd.tenant_id,
      reinstated_by: cmd.reinstated_by,
      reinstated_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: status}, %VoidGame{} = cmd) when status in [:pending, :disputed] do
    %GameVoided.V1{
      game_id: cmd.game_id,
      tenant_id: cmd.tenant_id,
      voided_by: cmd.voided_by,
      voided_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :voided}, %VoidGame{}) do
    {:error, :already_voided}
  end

  def execute(%__MODULE__{status: status}, cmd) do
    {:error, {:invalid_state, "Cannot execute #{inspect(cmd.__struct__)} in state #{inspect(status)}"}}
  end

  # ---------------------------------------------------------------------------
  # Event handlers (state mutation)
  # ---------------------------------------------------------------------------

  def apply(%__MODULE__{} = game, %GameLogged.V1{} = event) do
    %{game |
      game_id: event.game_id,
      tenant_id: event.tenant_id,
      team1_players: event.team1_players,
      team2_players: event.team2_players,
      confirmation_mode: event.confirmation_mode,
      status: :pending
    }
  end

  def apply(%__MODULE__{} = game, %GameConfirmed.V1{}) do
    %{game | status: :confirmed}
  end

  def apply(%__MODULE__{} = game, %GameDisputed.V1{}) do
    %{game | status: :disputed}
  end

  def apply(%__MODULE__{} = game, %GameReinstated.V1{}) do
    %{game | status: :confirmed}
  end

  def apply(%__MODULE__{} = game, %GameVoided.V1{}) do
    %{game | status: :voided}
  end

  # ---------------------------------------------------------------------------
  # Validation helpers
  # ---------------------------------------------------------------------------

  defp validate_players(%LogGame{team1_players: t1, team2_players: t2}) do
    all_players = t1 ++ t2

    if length(all_players) == length(Enum.uniq(all_players)) do
      :ok
    else
      {:error, :duplicate_player}
    end
  end

  defp validate_scores(%LogGame{rounds: rounds, points_per_round: max_points}) do
    invalid =
      Enum.any?(rounds, fn round ->
        Map.get(round, :team1_score, 0) > max_points or
          Map.get(round, :team2_score, 0) > max_points
      end)

    if invalid, do: {:error, :score_exceeds_limit}, else: :ok
  end

  defp validate_winning_condition(%LogGame{rounds: rounds, rounds_to_win: rounds_to_win}) do
    team1_wins = Enum.count(rounds, &(Map.get(&1, :team1_score, 0) > Map.get(&1, :team2_score, 0)))
    team2_wins = Enum.count(rounds, &(Map.get(&1, :team2_score, 0) > Map.get(&1, :team1_score, 0)))

    if team1_wins >= rounds_to_win or team2_wins >= rounds_to_win do
      :ok
    else
      {:error, :no_winner}
    end
  end
end
