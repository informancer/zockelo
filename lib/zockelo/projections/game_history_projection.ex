defmodule Zockelo.Projections.GameHistoryProjection do
  use Commanded.Projections.Ecto,
    application: Zockelo.CommandedApp,
    repo: Zockelo.Repo,
    name: __MODULE__

  import Ecto.Query

  alias Zockelo.Projections.{GameRead, GameRound}

  alias Zockelo.Domain.Events.{
    GameLogged,
    GameConfirmed,
    GameDisputed,
    GameReinstated,
    GameVoided
  }

  project(%GameLogged.V1{} = e, _meta, fn multi ->
    initial_status = if e.confirmation_mode == :trust, do: "confirmed", else: "pending"

    game_attrs = %{
      id: e.game_id,
      tenant_id: e.tenant_id,
      logged_by: e.logged_by,
      team1_players: e.team1_players,
      team2_players: e.team2_players,
      status: initial_status,
      confirmation_mode: to_string(e.confirmation_mode),
      rounds_to_win: e.rounds_to_win,
      points_per_round: e.points_per_round,
      logged_at: e.logged_at
    }

    round_inserts =
      e.rounds
      |> Enum.with_index(1)
      |> Enum.map(fn {round, position} ->
        %{
          game_id: e.game_id,
          tenant_id: e.tenant_id,
          position: position,
          team1_front_player_id: Map.get(round, :team1_front),
          team1_back_player_id: Map.get(round, :team1_back),
          team2_front_player_id: Map.get(round, :team2_front),
          team2_back_player_id: Map.get(round, :team2_back),
          team1_score: Map.get(round, :team1_score),
          team2_score: Map.get(round, :team2_score),
          inserted_at: DateTime.utc_now()
        }
      end)

    multi
    |> Ecto.Multi.insert(:game, GameRead.changeset(game_attrs))
    |> Ecto.Multi.insert_all(:rounds, GameRound, round_inserts)
  end)

  project(%GameConfirmed.V1{} = e, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :game, game_query(e.game_id),
      set: [status: "confirmed", confirmed_at: e.confirmed_at])
  end)

  project(%GameDisputed.V1{} = e, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :game, game_query(e.game_id),
      set: [status: "disputed", disputed_at: e.disputed_at])
  end)

  project(%GameReinstated.V1{game_id: id}, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :game, game_query(id), set: [status: "confirmed"])
  end)

  project(%GameVoided.V1{} = e, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :game, game_query(e.game_id),
      set: [status: "voided", voided_at: e.voided_at])
  end)

  defp game_query(id) do
    from g in GameRead, where: g.id == ^id
  end
end
