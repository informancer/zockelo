defmodule Zockelo.Games do
  @moduledoc """
  Context for game logging and retrieval.
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.CommandedApp
  alias Zockelo.Projections.{GameRead, GameRound, PlayerProfile, PlayerRating}
  alias Zockelo.Domain.Commands.LogGame

  # ---------------------------------------------------------------------------
  # Logging
  # ---------------------------------------------------------------------------

  @doc """
  Logs a game by dispatching the `LogGame` command.

  `attrs` map keys (all required):
    - `:tenant_id`, `:logged_by`
    - `:team1_players`, `:team2_players` — lists of player UUIDs
    - `:rounds` — list of round maps with score/position keys
    - `:confirmation_mode` — "trust" | "confirmation"
    - `:rounds_to_win`, `:points_per_round`

  Returns `{:ok, game_id}` or `{:error, reason}`.
  """
  def log_game(attrs) do
    game_id = Ecto.UUID.generate()

    cmd = %LogGame{
      game_id: game_id,
      tenant_id: attrs.tenant_id,
      logged_by: attrs.logged_by,
      team1_players: attrs.team1_players,
      team2_players: attrs.team2_players,
      rounds: normalize_rounds(attrs.rounds),
      confirmation_mode: parse_mode(attrs.confirmation_mode),
      rounds_to_win: attrs.rounds_to_win,
      points_per_round: attrs.points_per_round
    }

    case CommandedApp.dispatch(cmd) do
      :ok -> {:ok, game_id}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc """
  Returns `[{PlayerProfile, PlayerRating}]` for all active players in a tenant,
  sorted by rating descending.
  """
  def list_active_players_with_ratings(tenant_id) do
    profiles =
      Repo.all(
        from p in PlayerProfile,
          where: p.tenant_id == ^tenant_id and p.status != "deleted"
      )

    ratings_map =
      Repo.all(
        from r in PlayerRating,
          where: r.tenant_id == ^tenant_id
      )
      |> Map.new(& {&1.player_id, &1})

    profiles
    |> Enum.map(fn p ->
      rating = Map.get(ratings_map, p.player_id, %PlayerRating{
        player_id: p.player_id, tenant_id: tenant_id, rating: 1000,
        games_played: 0, wins: 0, losses: 0
      })
      {p, rating}
    end)
    |> Enum.sort_by(fn {_p, r} -> -r.rating end)
  end

  @doc "Returns all GameRead rows for a tenant, newest first."
  def list_games(tenant_id) do
    Repo.all(
      from g in GameRead,
        where: g.tenant_id == ^tenant_id,
        order_by: [desc: g.logged_at]
    )
  end

  @doc "Returns rounds for a game."
  def list_rounds(game_id) do
    Repo.all(
      from r in GameRound,
        where: r.game_id == ^game_id,
        order_by: r.position
    )
  end

  @doc "Gets a single game by id."
  def get_game(game_id), do: Repo.get(GameRead, game_id)

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Accept both atom-keyed and string-keyed round maps.
  defp normalize_rounds(rounds) do
    Enum.map(rounds, fn round ->
      %{
        team1_front: get_round_val(round, :team1_front, "team1_front"),
        team1_back: get_round_val(round, :team1_back, "team1_back"),
        team2_front: get_round_val(round, :team2_front, "team2_front"),
        team2_back: get_round_val(round, :team2_back, "team2_back"),
        team1_score: get_round_val(round, :team1_score, "team1_score") |> parse_int(),
        team2_score: get_round_val(round, :team2_score, "team2_score") |> parse_int()
      }
    end)
  end

  defp get_round_val(round, atom_key, string_key) do
    Map.get(round, atom_key) || Map.get(round, string_key)
  end

  defp parse_int(nil), do: 0
  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_mode("trust"), do: :trust
  defp parse_mode("confirmation"), do: :confirmation
  defp parse_mode(atom) when is_atom(atom), do: atom
end
