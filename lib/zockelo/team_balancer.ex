defmodule Zockelo.TeamBalancer do
  @moduledoc """
  Evaluates all valid team pairings for 2–4 players and returns the fairest split.

  Fairness is measured by minimising the absolute difference between team average ratings.
  Expected score is calculated using the standard Elo expected-score formula.
  """

  @doc """
  Given a list of `{PlayerProfile, PlayerRating}` tuples, returns the best team split.

  Returns a map:
    %{
      team1: [{profile, rating}, ...],
      team2: [{profile, rating}, ...],
      team1_avg: float,
      team2_avg: float,
      expected_score_team1: float,
      imbalance: float
    }

  Returns `nil` if fewer than 2 players are provided.
  """
  def balance(players) when length(players) < 2, do: nil

  def balance(players) do
    players
    |> generate_splits()
    |> Enum.min_by(fn %{imbalance: i} -> i end)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp generate_splits(players) do
    n = length(players)

    case n do
      2 ->
        [p1, p2] = players
        [make_split([p1], [p2])]

      3 ->
        # 2v1: pick each player as the solo side
        for i <- 0..2 do
          {solo, pair} = List.pop_at(players, i)
          make_split(pair, [solo])
        end

      4 ->
        [p1, p2, p3, p4] = players
        [
          make_split([p1, p2], [p3, p4]),
          make_split([p1, p3], [p2, p4]),
          make_split([p1, p4], [p2, p3])
        ]

      _ ->
        # For larger groups, use greedy 2v2 pairing of first 4
        players
        |> Enum.take(4)
        |> generate_splits()
    end
  end

  defp make_split(team1, team2) do
    avg1 = avg_rating(team1)
    avg2 = avg_rating(team2)
    expected1 = expected_score(avg1, avg2)

    %{
      team1: team1,
      team2: team2,
      team1_avg: avg1,
      team2_avg: avg2,
      expected_score_team1: expected1,
      imbalance: abs(avg1 - avg2)
    }
  end

  defp avg_rating(players) do
    ratings = Enum.map(players, fn {_profile, rating} -> rating.rating end)
    Enum.sum(ratings) / max(length(ratings), 1)
  end

  defp expected_score(rating_a, rating_b) do
    1.0 / (1.0 + :math.pow(10, (rating_b - rating_a) / 400.0))
  end
end
