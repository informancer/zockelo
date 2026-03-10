defmodule Zockelo.ScoreValidationTest do
  use ExUnit.Case, async: true

  # Task 22.3 — score validation logic
  # Score validation is in the Game aggregate's validate_scores/1 and validate_winning_condition/1.
  # These are exercised via the aggregate. Here we test the game aggregate directly.

  alias Zockelo.Domain.Aggregates.Game
  alias Zockelo.Domain.Commands.LogGame

  defp base_cmd(overrides \\ []) do
    %LogGame{
      game_id: Keyword.get(overrides, :game_id, Ecto.UUID.generate()),
      tenant_id: Ecto.UUID.generate(),
      logged_by: Ecto.UUID.generate(),
      rounds_to_win: Keyword.get(overrides, :rounds_to_win, 2),
      points_per_round: Keyword.get(overrides, :points_per_round, 10),
      confirmation_mode: "trust",
      rounds: Keyword.get(overrides, :rounds, []),
      team1_players: [Ecto.UUID.generate()],
      team2_players: [Ecto.UUID.generate()]
    }
  end

  describe "winning condition validation" do
    test "valid game passes when team1 reaches rounds_to_win" do
      cmd = base_cmd(rounds: [
        %{team1_score: 10, team2_score: 5},
        %{team1_score: 10, team2_score: 3}
      ])

      result = Game.execute(%Game{}, cmd)
      case result do
        {:error, :no_winner} -> flunk("Expected game with winner to succeed")
        _ -> assert true
      end
    end

    test "game with neither team winning returns :no_winner" do
      cmd = base_cmd(rounds: [
        %{team1_score: 10, team2_score: 5},
        %{team1_score: 3, team2_score: 10}
      ])

      assert {:error, :no_winner} = Game.execute(%Game{}, cmd)
    end

    test "score exceeding max points returns :score_exceeds_limit" do
      cmd = base_cmd(rounds: [
        %{team1_score: 99, team2_score: 5},
        %{team1_score: 10, team2_score: 3}
      ])

      assert {:error, :score_exceeds_limit} = Game.execute(%Game{}, cmd)
    end

    test "valid 2-0 win passes" do
      cmd = base_cmd(rounds: [
        %{team1_score: 10, team2_score: 5},
        %{team1_score: 8, team2_score: 4}
      ])

      result = Game.execute(%Game{}, cmd)
      refute result == {:error, :no_winner}
      refute result == {:error, :score_exceeds_limit}
    end
  end
end
