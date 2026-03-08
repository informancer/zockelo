defmodule Zockelo.Domain.Aggregates.GameTest do
  use ExUnit.Case, async: true

  alias Zockelo.Domain.Aggregates.Game

  alias Zockelo.Domain.Commands.{LogGame, ConfirmGame, DisputeGame, ReinstateGame, VoidGame}

  alias Zockelo.Domain.Events.{
    GameLogged,
    GameConfirmed,
    GameDisputed,
    GameReinstated,
    GameVoided
  }

  @game_id "00000000-0000-0000-0000-000000000020"
  @tenant_id "00000000-0000-0000-0000-000000000001"
  @player_a "player-aaa"
  @player_b "player-bbb"
  @player_c "player-ccc"
  @player_d "player-ddd"

  defp new_game, do: %Game{}

  # A valid 2v2 game: team1 wins 2 rounds, rounds_to_win=2, points_per_round=7
  defp valid_log_cmd(opts \\ []) do
    %LogGame{
      game_id: Keyword.get(opts, :game_id, @game_id),
      tenant_id: @tenant_id,
      logged_by: @player_a,
      team1_players: Keyword.get(opts, :team1, [@player_a, @player_b]),
      team2_players: Keyword.get(opts, :team2, [@player_c, @player_d]),
      rounds: Keyword.get(opts, :rounds, [
        %{team1_front: @player_a, team1_back: @player_b,
          team2_front: @player_c, team2_back: @player_d,
          team1_score: 7, team2_score: 4},
        %{team1_front: @player_a, team1_back: @player_b,
          team2_front: @player_c, team2_back: @player_d,
          team1_score: 7, team2_score: 5}
      ]),
      confirmation_mode: Keyword.get(opts, :mode, :confirmation),
      rounds_to_win: Keyword.get(opts, :rounds_to_win, 2),
      points_per_round: Keyword.get(opts, :points_per_round, 7)
    }
  end

  defp pending_game do
    event = Game.execute(new_game(), valid_log_cmd())
    Game.apply(new_game(), event)
  end

  defp confirmed_game do
    event = Game.execute(new_game(), valid_log_cmd(mode: :trust))
    # trust mode returns a list: [GameLogged.V1, GameConfirmed.V1]
    [logged_event, confirmed_event] = event
    new_game() |> Game.apply(logged_event) |> Game.apply(confirmed_event)
  end

  defp disputed_game do
    game = pending_game()
    event = Game.execute(game, %DisputeGame{game_id: @game_id, tenant_id: @tenant_id, disputed_by: @player_c})
    Game.apply(game, event)
  end

  # ---------------------------------------------------------------------------
  # LogGame — happy path
  # ---------------------------------------------------------------------------

  describe "LogGame — confirmation mode" do
    test "emits GameLogged event" do
      assert %GameLogged.V1{game_id: @game_id} = Game.execute(new_game(), valid_log_cmd())
    end

    test "game is :pending after log in confirmation mode" do
      assert pending_game().status == :pending
    end
  end

  describe "LogGame — trust mode" do
    test "emits [GameLogged, GameConfirmed] in trust mode" do
      result = Game.execute(new_game(), valid_log_cmd(mode: :trust))
      assert [%GameLogged.V1{}, %GameConfirmed.V1{}] = result
    end

    test "game is :confirmed after trust-mode log" do
      assert confirmed_game().status == :confirmed
    end
  end

  # ---------------------------------------------------------------------------
  # LogGame — validation
  # ---------------------------------------------------------------------------

  describe "LogGame — duplicate player validation" do
    test "rejects same player on both teams" do
      cmd = valid_log_cmd(team1: [@player_a, @player_b], team2: [@player_a, @player_d])
      assert {:error, :duplicate_player} = Game.execute(new_game(), cmd)
    end

    test "rejects same player twice on the same team" do
      cmd = valid_log_cmd(team1: [@player_a, @player_a], team2: [@player_c, @player_d])
      assert {:error, :duplicate_player} = Game.execute(new_game(), cmd)
    end

    test "accepts four distinct players" do
      assert %GameLogged.V1{} = Game.execute(new_game(), valid_log_cmd())
    end
  end

  describe "LogGame — score validation" do
    test "rejects score exceeding points_per_round" do
      cmd = valid_log_cmd(rounds: [
        %{team1_score: 8, team2_score: 4},
        %{team1_score: 7, team2_score: 3}
      ], points_per_round: 7)
      assert {:error, :score_exceeds_limit} = Game.execute(new_game(), cmd)
    end

    test "accepts score equal to points_per_round" do
      assert %GameLogged.V1{} = Game.execute(new_game(), valid_log_cmd())
    end
  end

  describe "LogGame — winning condition validation" do
    test "rejects game with no winner" do
      cmd = valid_log_cmd(rounds: [
        %{team1_score: 7, team2_score: 4}
      ], rounds_to_win: 2)
      assert {:error, :no_winner} = Game.execute(new_game(), cmd)
    end

    test "accepts game where team2 wins" do
      cmd = valid_log_cmd(rounds: [
        %{team1_score: 4, team2_score: 7},
        %{team1_score: 3, team2_score: 7}
      ])
      assert %GameLogged.V1{} = Game.execute(new_game(), cmd)
    end

    test "accepts game that goes to deciding round" do
      cmd = valid_log_cmd(rounds_to_win: 2, rounds: [
        %{team1_score: 7, team2_score: 4},
        %{team1_score: 3, team2_score: 7},
        %{team1_score: 7, team2_score: 5}
      ])
      assert %GameLogged.V1{} = Game.execute(new_game(), cmd)
    end
  end

  # ---------------------------------------------------------------------------
  # ConfirmGame
  # ---------------------------------------------------------------------------

  describe "ConfirmGame" do
    test "confirms a pending game" do
      cmd = %ConfirmGame{game_id: @game_id, tenant_id: @tenant_id, confirmed_by: @player_c}
      assert %GameConfirmed.V1{} = Game.execute(pending_game(), cmd)
      event = Game.execute(pending_game(), cmd)
      assert Game.apply(pending_game(), event).status == :confirmed
    end

    test "cannot confirm an already confirmed game" do
      cmd = %ConfirmGame{game_id: @game_id, tenant_id: @tenant_id, confirmed_by: @player_c}
      assert {:error, _} = Game.execute(confirmed_game(), cmd)
    end
  end

  # ---------------------------------------------------------------------------
  # DisputeGame
  # ---------------------------------------------------------------------------

  describe "DisputeGame" do
    test "disputes a pending game" do
      cmd = %DisputeGame{game_id: @game_id, tenant_id: @tenant_id, disputed_by: @player_c, reason: nil}
      assert %GameDisputed.V1{} = Game.execute(pending_game(), cmd)
      event = Game.execute(pending_game(), cmd)
      assert Game.apply(pending_game(), event).status == :disputed
    end

    test "cannot dispute a confirmed game" do
      cmd = %DisputeGame{game_id: @game_id, tenant_id: @tenant_id, disputed_by: @player_c, reason: nil}
      assert {:error, _} = Game.execute(confirmed_game(), cmd)
    end
  end

  # ---------------------------------------------------------------------------
  # ReinstateGame
  # ---------------------------------------------------------------------------

  describe "ReinstateGame" do
    test "reinstates a disputed game to confirmed" do
      cmd = %ReinstateGame{game_id: @game_id, tenant_id: @tenant_id, reinstated_by: "admin"}
      assert %GameReinstated.V1{} = Game.execute(disputed_game(), cmd)
      event = Game.execute(disputed_game(), cmd)
      assert Game.apply(disputed_game(), event).status == :confirmed
    end

    test "cannot reinstate a pending game" do
      cmd = %ReinstateGame{game_id: @game_id, tenant_id: @tenant_id, reinstated_by: "admin"}
      assert {:error, _} = Game.execute(pending_game(), cmd)
    end
  end

  # ---------------------------------------------------------------------------
  # VoidGame
  # ---------------------------------------------------------------------------

  describe "VoidGame" do
    test "voids a disputed game" do
      cmd = %VoidGame{game_id: @game_id, tenant_id: @tenant_id, voided_by: "admin"}
      assert %GameVoided.V1{} = Game.execute(disputed_game(), cmd)
      event = Game.execute(disputed_game(), cmd)
      assert Game.apply(disputed_game(), event).status == :voided
    end

    test "cannot void an already voided game" do
      cmd = %VoidGame{game_id: @game_id, tenant_id: @tenant_id, voided_by: "admin"}
      event = Game.execute(disputed_game(), cmd)
      voided = Game.apply(disputed_game(), event)
      assert {:error, :already_voided} = Game.execute(voided, cmd)
    end

    test "cannot void a pending game" do
      cmd = %VoidGame{game_id: @game_id, tenant_id: @tenant_id, voided_by: "admin"}
      assert {:error, _} = Game.execute(pending_game(), cmd)
    end
  end

  # ---------------------------------------------------------------------------
  # Router stream ID helpers
  # ---------------------------------------------------------------------------

  describe "Router.player_stream_id/1" do
    test "formats tenant-scoped stream name" do
      cmd = %{tenant_id: "t1", player_id: "p1"}
      assert Zockelo.Domain.Router.player_stream_id(cmd) == "tenant-t1-players-p1"
    end
  end

  describe "Router.game_stream_id/1" do
    test "formats tenant-scoped stream name" do
      cmd = %{tenant_id: "t1", game_id: "g1"}
      assert Zockelo.Domain.Router.game_stream_id(cmd) == "tenant-t1-games-g1"
    end
  end
end
