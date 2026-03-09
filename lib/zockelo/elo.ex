defmodule Zockelo.Elo do
  @moduledoc """
  Elo rating calculation for Zockelo.

  Ratings live exclusively in projections — this module is called by projection
  handlers when a game is confirmed. Events never contain ratings.

  ## Formula

      team_avg  = average of player ratings on team
      expected  = 1 / (1 + 10 ^ ((opponent_avg - our_avg) / 400))
      delta     = K × (actual - expected)   # actual: 1 = win, 0 = loss

  Each player's delta uses their own K-factor. Ratings are floored at 100.

  ## K-factor decay by rating

      < 1400  → K = 40
      1400–1799 → K = 32
      ≥ 1800  → K = 20
  """

  @rating_floor 100

  @doc "Returns the K-factor for a given rating."
  def k_factor(rating) when rating < 1400, do: 40
  def k_factor(rating) when rating < 1800, do: 32
  def k_factor(_rating), do: 20

  @doc """
  Expected score for a team with `our_avg` rating against `their_avg`.
  Returns a float in (0, 1).
  """
  def expected_score(our_avg, their_avg) do
    1.0 / (1.0 + :math.pow(10, (their_avg - our_avg) / 400.0))
  end

  @doc """
  Calculates new ratings after team1 beats team2.

  Each element in `team1` and `team2` must be a map with `:player_id` and
  `:rating` keys. Returns `%{team1: [...], team2: [...]}` with updated ratings.
  Rating floor of #{@rating_floor} is applied.
  """
  def calculate(team1, team2) do
    avg1 = team_avg(team1)
    avg2 = team_avg(team2)

    exp1 = expected_score(avg1, avg2)
    exp2 = 1.0 - exp1

    updated1 = Enum.map(team1, &update_player(&1, 1.0, exp1))
    updated2 = Enum.map(team2, &update_player(&1, 0.0, exp2))

    %{team1: updated1, team2: updated2}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp team_avg(players) do
    Enum.sum(Enum.map(players, & &1.rating)) / length(players)
  end

  defp update_player(%{rating: rating} = player, actual, expected) do
    k = k_factor(rating)
    delta = k * (actual - expected)
    new_rating = max(@rating_floor, round(rating + delta))
    %{player | rating: new_rating}
  end
end
