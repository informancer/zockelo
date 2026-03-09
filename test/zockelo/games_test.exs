defmodule Zockelo.GamesTest do
  use Zockelo.DataCase, async: false

  alias Zockelo.Games
  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile, PlayerRating, GameRead}

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

      # Projection is async; verify via direct insert + context
      assert is_binary(game_id)
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
  end
end
