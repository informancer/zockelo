defmodule Zockelo.EloFloorTest do
  use ExUnit.Case, async: true

  alias Zockelo.Elo

  # Task 22.50 — rating floor: result clamped to 100 when delta would push below floor
  describe "rating floor" do
    test "low-rated player losing to high-rated does not go below 100" do
      # A very low-rated player (at floor) loses to a very high-rated player
      team1 = [%{player_id: "low", rating: 100}]
      team2 = [%{player_id: "high", rating: 2000}]

      # team2 wins: team1 players get 0 (loss), team2 gets 1 (win)
      result = Elo.calculate(team1, team2)
      # team1 was the loser in this default scenario (team1 wins default)
      # Let's verify by checking the calculate/3 fallback
      # calculate/2 assumes team1 wins; to test floor, let's check team2 winning
      # We need to check by using the result where team1 loses
      # Actually calculate/2 assumes team1 wins. Let's swap:
      result2 = Elo.calculate(team2, team1)
      # In result2, team1 = high player (wins), team2 = low player (loses)
      low_new = result2.team2 |> hd() |> Map.get(:rating)
      assert low_new >= 100
    end

    test "player at 100 rating stays at 100 after a loss" do
      # Swap teams so high-rated is team1 (wins) and low-rated is team2 (loses)
      winner = [%{player_id: "high", rating: 2500}]
      loser = [%{player_id: "low", rating: 100}]

      result = Elo.calculate(winner, loser)
      low_new = result.team2 |> hd() |> Map.get(:rating)

      assert low_new == 100
    end
  end
end
