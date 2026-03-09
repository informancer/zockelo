defmodule Zockelo.Projections.GameHistoryProjectionTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Projections.{GameHistoryProjection, GameRead, GameRound}
  alias Zockelo.Repo
  import Ecto.Query

  alias Zockelo.Domain.Events.{
    GameLogged,
    GameConfirmed,
    GameDisputed,
    GameReinstated,
    GameVoided
  }

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @game_id   "00000000-0000-0000-0000-000000000020"
  @p1 "00000000-0000-0000-0000-000000000010"
  @p2 "00000000-0000-0000-0000-000000000011"
  @p3 "00000000-0000-0000-0000-000000000012"
  @p4 "00000000-0000-0000-0000-000000000013"

  defp meta, do: %{handler_name: "GameHistoryProjection", event_number: System.unique_integer([:positive, :monotonic])}
  defp handle(event), do: GameHistoryProjection.handle(event, meta())

  defp log_game(opts \\ []) do
    handle(%GameLogged.V1{
      game_id: Keyword.get(opts, :game_id, @game_id),
      tenant_id: @tenant_id,
      logged_by: @p1,
      team1_players: [@p1, @p2],
      team2_players: [@p3, @p4],
      rounds: [
        %{team1_front: @p1, team1_back: @p2, team2_front: @p3, team2_back: @p4,
          team1_score: 7, team2_score: 4},
        %{team1_front: @p1, team1_back: @p2, team2_front: @p3, team2_back: @p4,
          team1_score: 7, team2_score: 5}
      ],
      confirmation_mode: Keyword.get(opts, :mode, :confirmation),
      rounds_to_win: 2,
      points_per_round: 7,
      logged_at: DateTime.utc_now()
    })
  end

  describe "GameLogged" do
    test "creates a game row" do
      :ok = log_game()
      game = Repo.get(GameRead, @game_id)
      assert game.tenant_id == @tenant_id
      assert game.status == "pending"
    end

    test "creates game_round rows with positions" do
      :ok = log_game()
      rounds = Repo.all(from r in GameRound, where: r.game_id == ^@game_id, order_by: r.position)
      assert length(rounds) == 2
      assert hd(rounds).team1_front_player_id == @p1
      assert hd(rounds).team1_score == 7
    end

    test "trust mode game is immediately confirmed" do
      :ok = log_game(mode: :trust)
      assert Repo.get(GameRead, @game_id).status == "confirmed"
    end
  end

  describe "GameConfirmed" do
    setup do: log_game()

    test "transitions game to confirmed" do
      :ok = handle(%GameConfirmed.V1{
        game_id: @game_id, tenant_id: @tenant_id,
        confirmed_by: @p3, confirmed_at: DateTime.utc_now()
      })
      assert Repo.get(GameRead, @game_id).status == "confirmed"
    end
  end

  describe "GameDisputed" do
    setup do: log_game()

    test "transitions game to disputed" do
      :ok = handle(%GameDisputed.V1{
        game_id: @game_id, tenant_id: @tenant_id,
        disputed_by: @p3, reason: nil, disputed_at: DateTime.utc_now()
      })
      assert Repo.get(GameRead, @game_id).status == "disputed"
    end
  end

  describe "GameReinstated" do
    setup do
      log_game()
      handle(%GameDisputed.V1{
        game_id: @game_id, tenant_id: @tenant_id,
        disputed_by: @p3, reason: nil, disputed_at: DateTime.utc_now()
      })
    end

    test "transitions game back to confirmed" do
      :ok = handle(%GameReinstated.V1{
        game_id: @game_id, tenant_id: @tenant_id,
        reinstated_by: "admin", reinstated_at: DateTime.utc_now()
      })
      assert Repo.get(GameRead, @game_id).status == "confirmed"
    end
  end

  describe "GameVoided" do
    setup do
      log_game()
      handle(%GameDisputed.V1{
        game_id: @game_id, tenant_id: @tenant_id,
        disputed_by: @p3, reason: nil, disputed_at: DateTime.utc_now()
      })
    end

    test "transitions game to voided" do
      :ok = handle(%GameVoided.V1{
        game_id: @game_id, tenant_id: @tenant_id,
        voided_by: "admin", voided_at: DateTime.utc_now()
      })
      assert Repo.get(GameRead, @game_id).status == "voided"
    end
  end
end
