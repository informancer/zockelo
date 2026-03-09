defmodule Zockelo.EloTest do
  use ExUnit.Case, async: true

  alias Zockelo.Elo

  # ---------------------------------------------------------------------------
  # k_factor/1
  # ---------------------------------------------------------------------------

  describe "k_factor/1" do
    test "returns 40 for rating below 1400" do
      assert Elo.k_factor(1000) == 40
      assert Elo.k_factor(1399) == 40
    end

    test "returns 32 for rating 1400–1799" do
      assert Elo.k_factor(1400) == 32
      assert Elo.k_factor(1799) == 32
    end

    test "returns 20 for rating 1800 and above" do
      assert Elo.k_factor(1800) == 20
      assert Elo.k_factor(2400) == 20
    end
  end

  # ---------------------------------------------------------------------------
  # expected_score/2
  # ---------------------------------------------------------------------------

  describe "expected_score/2" do
    test "returns 0.5 when both teams have equal average rating" do
      assert Elo.expected_score(1000, 1000) == 0.5
    end

    test "higher-rated team has expected score above 0.5" do
      score = Elo.expected_score(1200, 1000)
      assert score > 0.5
    end

    test "lower-rated team has expected score below 0.5" do
      score = Elo.expected_score(1000, 1200)
      assert score < 0.5
    end

    test "expected scores of both sides sum to 1.0" do
      e1 = Elo.expected_score(1200, 1000)
      e2 = Elo.expected_score(1000, 1200)
      assert_in_delta e1 + e2, 1.0, 0.0001
    end
  end

  # ---------------------------------------------------------------------------
  # calculate/2
  # ---------------------------------------------------------------------------

  describe "calculate/2 — equal teams, one win each" do
    # Two 1000-rated players per team, team1 wins
    @team1 [%{player_id: "p1", rating: 1000}, %{player_id: "p2", rating: 1000}]
    @team2 [%{player_id: "p3", rating: 1000}, %{player_id: "p4", rating: 1000}]

    test "winners gain rating" do
      %{team1: updated1} = Elo.calculate(@team1, @team2)
      assert Enum.all?(updated1, fn p -> p.rating > 1000 end)
    end

    test "losers lose rating" do
      %{team2: updated2} = Elo.calculate(@team1, @team2)
      assert Enum.all?(updated2, fn p -> p.rating < 1000 end)
    end

    test "total rating is conserved (zero-sum)" do
      %{team1: t1, team2: t2} = Elo.calculate(@team1, @team2)
      before_total = Enum.sum(Enum.map(@team1 ++ @team2, & &1.rating))
      after_total = Enum.sum(Enum.map(t1 ++ t2, & &1.rating))
      assert_in_delta before_total, after_total, 0.01
    end

    test "winners gain exactly what losers lose (symmetric)" do
      %{team1: t1, team2: t2} = Elo.calculate(@team1, @team2)
      team1_gain = Enum.sum(Enum.map(t1, & &1.rating)) - Enum.sum(Enum.map(@team1, & &1.rating))
      team2_loss = Enum.sum(Enum.map(@team2, & &1.rating)) - Enum.sum(Enum.map(t2, & &1.rating))
      assert_in_delta team1_gain, team2_loss, 0.01
    end
  end

  describe "calculate/2 — higher-rated team loses (upset)" do
    @strong [%{player_id: "p1", rating: 1800}, %{player_id: "p2", rating: 1800}]
    @weak   [%{player_id: "p3", rating: 1000}, %{player_id: "p4", rating: 1000}]

    test "upset winners gain more than a favoured win would" do
      # weak team wins — they should gain more than in an equal match
      %{team1: gained} = Elo.calculate(@weak, @strong)
      %{team1: normal} = Elo.calculate(
        [%{player_id: "p1", rating: 1000}, %{player_id: "p2", rating: 1000}],
        [%{player_id: "p3", rating: 1000}, %{player_id: "p4", rating: 1000}]
      )
      upset_gain = hd(gained).rating - 1000
      normal_gain = hd(normal).rating - 1000
      assert upset_gain > normal_gain
    end

    test "heavy favourite loses more rating in an upset than a normal loss" do
      %{team2: lost} = Elo.calculate(@weak, @strong)
      assert hd(lost).rating < 1800
    end
  end

  describe "calculate/2 — K-factor applied per player" do
    test "low-rated players move more than high-rated players in same game" do
      low  = [%{player_id: "p1", rating: 1000}]
      high = [%{player_id: "p2", rating: 1800}]
      # low wins
      %{team1: [low_after], team2: [high_after]} = Elo.calculate(low, high)
      low_gain  = low_after.rating  - 1000
      high_loss = 1800 - high_after.rating
      assert low_gain > high_loss
    end
  end

  describe "calculate/2 — rating floor" do
    test "rating never drops below 100" do
      very_weak = [%{player_id: "p1", rating: 101}]
      very_strong = [%{player_id: "p2", rating: 2400}]
      # very_weak loses
      %{team2: [p]} = Elo.calculate(very_strong, very_weak)
      assert p.rating >= 100
    end
  end

  describe "calculate/2 — 1v1" do
    test "works with single player per team" do
      team1 = [%{player_id: "p1", rating: 1000}]
      team2 = [%{player_id: "p2", rating: 1000}]
      %{team1: [winner], team2: [loser]} = Elo.calculate(team1, team2)
      assert winner.rating > 1000
      assert loser.rating < 1000
    end
  end
end
