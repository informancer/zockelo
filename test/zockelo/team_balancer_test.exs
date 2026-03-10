defmodule Zockelo.TeamBalancerTest do
  use ExUnit.Case, async: true

  alias Zockelo.TeamBalancer

  # Task 22.2 — unit tests for team balancer algorithm
  # TeamBalancer.balance/1 takes [{profile, rating}, ...] tuples

  defp make_player(id, rating) do
    profile = %{player_id: id, display_name: id, status: "active"}
    r = %{rating: rating, games_played: 0, wins: 0, losses: 0}
    {profile, r}
  end

  describe "balance/1 with fewer than 2 players" do
    test "returns nil for 0 players" do
      assert nil == TeamBalancer.balance([])
    end

    test "returns nil for 1 player" do
      assert nil == TeamBalancer.balance([make_player("a", 1000)])
    end
  end

  describe "balance/1 with 2 players (1v1)" do
    test "returns a split with one player per team" do
      result = TeamBalancer.balance([make_player("a", 1000), make_player("b", 1200)])
      assert is_map(result)
      assert length(result.team1) == 1
      assert length(result.team2) == 1
    end

    test "both players are included" do
      result = TeamBalancer.balance([make_player("a", 1000), make_player("b", 1200)])
      all_ids = (result.team1 ++ result.team2) |> Enum.map(fn {p, _} -> p.player_id end) |> Enum.sort()
      assert all_ids == ["a", "b"]
    end
  end

  describe "balance/1 with 3 players (2v1)" do
    test "returns a split covering all 3 players" do
      players = Enum.map([{"a", 1000}, {"b", 1200}, {"c", 1100}], fn {id, r} -> make_player(id, r) end)
      result = TeamBalancer.balance(players)
      assert is_map(result)
      total = length(result.team1) + length(result.team2)
      assert total == 3
    end
  end

  describe "balance/1 with 4 players (2v2)" do
    test "returns a 2v2 split" do
      players = Enum.map([{"a", 1000}, {"b", 1200}, {"c", 1100}, {"d", 900}], fn {id, r} -> make_player(id, r) end)
      result = TeamBalancer.balance(players)
      assert is_map(result)
      assert length(result.team1) == 2
      assert length(result.team2) == 2
    end

    test "best pairing minimises rating imbalance" do
      # Best: (b=1200 + d=900) vs (a=1000 + c=1100) → 1050 vs 1050 → imbalance 0
      players = Enum.map([{"a", 1000}, {"b", 1200}, {"c", 1100}, {"d", 900}], fn {id, r} -> make_player(id, r) end)
      result = TeamBalancer.balance(players)
      assert result.imbalance <= 50
    end

    test "all players appear exactly once" do
      players = Enum.map([{"a", 1000}, {"b", 1200}, {"c", 1100}, {"d", 900}], fn {id, r} -> make_player(id, r) end)
      result = TeamBalancer.balance(players)
      all_ids = (result.team1 ++ result.team2) |> Enum.map(fn {p, _} -> p.player_id end) |> Enum.sort()
      assert all_ids == ["a", "b", "c", "d"]
    end
  end
end
