defmodule Zockelo.Projections.PlayerRatingsProjection do
  use Commanded.Projections.Ecto,
    application: Zockelo.CommandedApp,
    repo: Zockelo.Repo,
    name: __MODULE__

  import Ecto.Query

  alias Zockelo.Elo
  alias Zockelo.Projections.{PlayerRating, GameRound}

  alias Zockelo.Domain.Events.{
    PlayerActivated,
    PlayerDeleted,
    GameLogged,
    GameConfirmed
  }

  # New player starts at 1000
  project(%PlayerActivated.V1{} = e, _meta, fn multi ->
    Ecto.Multi.insert(multi, :rating, PlayerRating.changeset(%{
      player_id: e.player_id,
      tenant_id: e.tenant_id,
      rating: 1000,
      games_played: 0,
      wins: 0,
      losses: 0
    }))
  end)

  # Trust mode: update ratings immediately on GameLogged
  project(%GameLogged.V1{confirmation_mode: :trust} = e, _meta, fn multi ->
    Ecto.Multi.run(multi, :ratings, fn repo, _changes ->
      apply_elo(repo, e.game_id, e.tenant_id, e.team1_players, e.team2_players, e.rounds)
    end)
  end)

  # Confirmation mode: skip — wait for GameConfirmed
  project(%GameLogged.V1{confirmation_mode: :confirmation}, _meta, fn multi -> multi end)

  # Confirmation mode: update ratings on GameConfirmed
  project(%GameConfirmed.V1{} = e, _meta, fn multi ->
    Ecto.Multi.run(multi, :ratings, fn repo, _changes ->
      case repo.get_by(Zockelo.Projections.GameRead, id: e.game_id) do
        nil ->
          # Game not in read model yet (trust mode games are already confirmed)
          {:ok, :skipped}

        game ->
          apply_elo(repo, game.id, game.tenant_id, game.team1_players, game.team2_players,
            rounds_for_game(repo, game.id))
      end
    end)
  end)

  project(%PlayerDeleted.V1{} = e, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :rating,
      from(r in PlayerRating, where: r.player_id == ^e.player_id),
      set: [deleted: true])
  end)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp apply_elo(repo, game_id, tenant_id, team1_ids, team2_ids, rounds) do
    team1 = load_players(repo, team1_ids)
    team2 = load_players(repo, team2_ids)

    %{team1: updated1, team2: updated2} = Elo.calculate(team1, team2)

    # Calculate per-round deltas for profile history (averaged across rounds)
    team1_delta = avg_delta(team1, updated1)
    team2_delta = avg_delta(team2, updated2)

    # Write rating deltas back to game_rounds
    write_round_deltas(repo, game_id, tenant_id, rounds, team1_delta, team2_delta)

    # Persist updated ratings
    for %{player_id: pid, rating: new_rating} <- updated1 ++ updated2 do
      repo.update_all(
        from(r in PlayerRating, where: r.player_id == ^pid),
        inc: [games_played: 1],
        set: [rating: new_rating]
      )
    end

    # Increment wins/losses
    team1_ids_set = MapSet.new(Enum.map(updated1, & &1.player_id))
    all_ids = team1_ids ++ team2_ids

    for pid <- all_ids do
      {wins_inc, losses_inc} =
        if MapSet.member?(team1_ids_set, pid), do: {1, 0}, else: {0, 1}
      repo.update_all(
        from(r in PlayerRating, where: r.player_id == ^pid),
        inc: [wins: wins_inc, losses: losses_inc]
      )
    end

    {:ok, :done}
  end

  defp load_players(repo, ids) do
    Enum.map(ids, fn id ->
      case repo.get(PlayerRating, id) do
        nil -> %{player_id: id, rating: 1000}
        row -> %{player_id: id, rating: row.rating}
      end
    end)
  end

  defp avg_delta(before_players, after_players) do
    deltas =
      Enum.zip(before_players, after_players)
      |> Enum.map(fn {b, a} -> a.rating - b.rating end)

    Enum.sum(deltas) / max(length(deltas), 1)
  end

  defp write_round_deltas(repo, game_id, _tenant_id, _rounds, team1_delta, team2_delta) do
    repo.update_all(
      from(r in GameRound, where: r.game_id == ^game_id),
      set: [team1_rating_delta: team1_delta, team2_rating_delta: team2_delta]
    )
  end

  defp rounds_for_game(repo, game_id) do
    repo.all(from r in GameRound, where: r.game_id == ^game_id)
  end
end
