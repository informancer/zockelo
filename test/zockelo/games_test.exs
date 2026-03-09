defmodule Zockelo.GamesTest do
  use Zockelo.DataCase, async: false

  alias Zockelo.Games
  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile, PlayerRating, GameRead}

  import Ecto.Query

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @p1 "00000000-0000-0000-0000-000000000010"
  @p2 "00000000-0000-0000-0000-000000000011"
  @p3 "00000000-0000-0000-0000-000000000012"
  @p4 "00000000-0000-0000-0000-000000000013"

  defp insert_tenant(config \\ %{}) do
    default = %{"rounds_to_win" => 2, "points_per_round" => 7,
                "confirmation_mode" => "trust"}
    Repo.insert!(%TenantRead{
      id: @tenant_id, slug: "acme", name: "Acme",
      status: "active", config: Map.merge(default, config)
    })
  end

  defp insert_player(player_id) do
    Repo.insert!(%PlayerProfile{
      player_id: player_id, tenant_id: @tenant_id,
      role: "player", status: "active"
    })
    Repo.insert!(%PlayerRating{
      player_id: player_id, tenant_id: @tenant_id,
      rating: 1000, games_played: 0, wins: 0, losses: 0
    })
  end

  defp two_round_win do
    [
      %{team1_score: 7, team2_score: 3},
      %{team1_score: 7, team2_score: 4}
    ]
  end

  defp log_pending_game do
    {:ok, game_id} = Games.log_game(%{
      tenant_id: @tenant_id,
      logged_by: @p1,
      team1_players: [@p1, @p2],
      team2_players: [@p3, @p4],
      rounds: two_round_win(),
      confirmation_mode: "confirmation",
      rounds_to_win: 2,
      points_per_round: 7
    })
    game_id
  end

  describe "log_game/1 — trust mode" do
    setup do
      insert_tenant()
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "creates a GameRead record with status confirmed" do
      {:ok, game_id} = Games.log_game(%{
        tenant_id: @tenant_id,
        logged_by: @p1,
        team1_players: [@p1, @p2],
        team2_players: [@p3, @p4],
        rounds: two_round_win(),
        confirmation_mode: "trust",
        rounds_to_win: 2,
        points_per_round: 7
      })

      assert is_binary(game_id)
      assert %GameRead{status: "confirmed"} = Repo.get(GameRead, game_id)
    end

    test "returns error for duplicate player" do
      assert {:error, :duplicate_player} = Games.log_game(%{
        tenant_id: @tenant_id,
        logged_by: @p1,
        team1_players: [@p1, @p2],
        team2_players: [@p1, @p4],
        rounds: two_round_win(),
        confirmation_mode: "trust",
        rounds_to_win: 2,
        points_per_round: 7
      })
    end

    test "returns error when score exceeds points_per_round" do
      rounds = [%{team1_score: 10, team2_score: 3}, %{team1_score: 7, team2_score: 4}]
      assert {:error, :score_exceeds_limit} = Games.log_game(%{
        tenant_id: @tenant_id,
        logged_by: @p1,
        team1_players: [@p1, @p2],
        team2_players: [@p3, @p4],
        rounds: rounds,
        confirmation_mode: "trust",
        rounds_to_win: 2,
        points_per_round: 7
      })
    end

    test "returns error when no team wins enough rounds" do
      rounds = [%{team1_score: 7, team2_score: 3}]
      assert {:error, :no_winner} = Games.log_game(%{
        tenant_id: @tenant_id,
        logged_by: @p1,
        team1_players: [@p1, @p2],
        team2_players: [@p3, @p4],
        rounds: rounds,
        confirmation_mode: "trust",
        rounds_to_win: 2,
        points_per_round: 7
      })
    end
  end

  describe "log_game/1 — confirmation mode" do
    setup do
      insert_tenant(%{"confirmation_mode" => "confirmation"})
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "creates a GameRead record with status pending" do
      game_id = log_pending_game()
      assert %GameRead{status: "pending"} = Repo.get(GameRead, game_id)
    end
  end

  describe "log_game/1 — 1v1 mode" do
    setup do
      insert_tenant()
      Enum.each([@p1, @p3], &insert_player/1)
      :ok
    end

    test "accepts single player per team" do
      {:ok, game_id} = Games.log_game(%{
        tenant_id: @tenant_id,
        logged_by: @p1,
        team1_players: [@p1],
        team2_players: [@p3],
        rounds: two_round_win(),
        confirmation_mode: "trust",
        rounds_to_win: 2,
        points_per_round: 7
      })

      assert is_binary(game_id)
    end
  end

  describe "confirm_game/2" do
    setup do
      insert_tenant(%{"confirmation_mode" => "confirmation"})
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "confirms a pending game" do
      game_id = log_pending_game()
      assert :ok = Games.confirm_game(game_id, @p1)
    end

    test "returns error when game not found" do
      assert {:error, :not_found} = Games.confirm_game(Ecto.UUID.generate(), @p1)
    end
  end

  describe "dispute_game/3" do
    setup do
      insert_tenant(%{"confirmation_mode" => "confirmation"})
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "disputes a pending game" do
      game_id = log_pending_game()
      assert :ok = Games.dispute_game(game_id, @p1, "Wrong score")
    end

    test "returns error when game not found" do
      assert {:error, :not_found} = Games.dispute_game(Ecto.UUID.generate(), @p1, nil)
    end
  end

  describe "reinstate_game/2" do
    setup do
      insert_tenant(%{"confirmation_mode" => "confirmation"})
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "reinstates a disputed game" do
      game_id = log_pending_game()
      :ok = Games.dispute_game(game_id, @p1, nil)
      # Update read model to reflect disputed state for reinstate lookup
      Repo.update_all(from(g in GameRead, where: g.id == ^game_id), set: [status: "disputed"])
      assert :ok = Games.reinstate_game(game_id, @p1)
    end
  end

  describe "void_game/2" do
    setup do
      insert_tenant(%{"confirmation_mode" => "confirmation"})
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "voids a pending game directly" do
      game_id = log_pending_game()
      assert :ok = Games.void_game(game_id, @p1)
    end

    test "voids a disputed game" do
      game_id = log_pending_game()
      :ok = Games.dispute_game(game_id, @p1, nil)
      Repo.update_all(from(g in GameRead, where: g.id == ^game_id), set: [status: "disputed"])
      assert :ok = Games.void_game(game_id, @p1)
    end

    test "returns error when game not found" do
      assert {:error, :not_found} = Games.void_game(Ecto.UUID.generate(), @p1)
    end
  end

  describe "list_pending_games/1 and list_disputed_games/1" do
    setup do
      insert_tenant(%{"confirmation_mode" => "confirmation"})
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "lists pending games for tenant" do
      game_id = log_pending_game()
      pending = Games.list_pending_games(@tenant_id)
      assert Enum.any?(pending, &(&1.id == game_id))
    end

    test "lists disputed games for tenant" do
      game_id = log_pending_game()
      :ok = Games.dispute_game(game_id, @p1, nil)
      Repo.update_all(from(g in GameRead, where: g.id == ^game_id), set: [status: "disputed"])
      disputed = Games.list_disputed_games(@tenant_id)
      assert Enum.any?(disputed, &(&1.id == game_id))
    end
  end

  describe "void_player_games/3" do
    setup do
      insert_tenant(%{"confirmation_mode" => "confirmation"})
      Enum.each([@p1, @p2, @p3, @p4], &insert_player/1)
      :ok
    end

    test "voids pending games for a deleted player" do
      _game_id = log_pending_game()
      assert :ok = Games.void_player_games(@p1, @tenant_id, @p1)
    end
  end

  describe "list_active_players_with_ratings/1" do
    setup do
      insert_tenant()
      Enum.each([@p1, @p2], &insert_player/1)
      :ok
    end

    test "returns players with ratings joined" do
      players = Games.list_active_players_with_ratings(@tenant_id)
      assert length(players) == 2
      assert Enum.all?(players, fn {_profile, rating} -> rating.rating == 1000 end)
    end

    test "excludes deleted players" do
      Repo.update_all(
        from(p in PlayerProfile, where: p.player_id == ^@p1),
        set: [status: "deleted"]
      )
      players = Games.list_active_players_with_ratings(@tenant_id)
      assert length(players) == 1
    end

    test "sorts by rating desc then games_played desc" do
      Repo.update_all(
        from(r in PlayerRating, where: r.player_id == ^@p2),
        set: [rating: 1200, games_played: 5]
      )
      [{first, _}, {second, _}] = Games.list_active_players_with_ratings(@tenant_id)
      assert first.player_id == @p2
      assert second.player_id == @p1
    end
  end
end
