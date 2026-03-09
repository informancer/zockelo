defmodule Zockelo.Projections.PlayerRatingsProjectionTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Projections.{PlayerRatingsProjection, PlayerRating, GameRead}
  alias Zockelo.Repo

  alias Zockelo.Domain.Events.{PlayerActivated, PlayerDeleted, GameConfirmed, GameLogged}

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @p1 "00000000-0000-0000-0000-000000000010"
  @p2 "00000000-0000-0000-0000-000000000011"
  @p3 "00000000-0000-0000-0000-000000000012"
  @p4 "00000000-0000-0000-0000-000000000013"
  @game_id "00000000-0000-0000-0000-000000000020"

  defp meta, do: %{handler_name: "PlayerRatingsProjection", event_number: System.unique_integer([:positive, :monotonic])}
  defp handle(event), do: PlayerRatingsProjection.handle(event, meta())

  defp activate(player_id) do
    handle(%PlayerActivated.V1{
      player_id: player_id, tenant_id: @tenant_id,
      encrypted_name: "enc", activated_at: DateTime.utc_now()
    })
  end

  defp game_logged_event(opts \\ []) do
    %GameLogged.V1{
      game_id: Keyword.get(opts, :game_id, @game_id),
      tenant_id: @tenant_id,
      logged_by: @p1,
      team1_players: Keyword.get(opts, :team1, [@p1, @p2]),
      team2_players: Keyword.get(opts, :team2, [@p3, @p4]),
      rounds: [
        %{team1_score: 7, team2_score: 4},
        %{team1_score: 7, team2_score: 5}
      ],
      confirmation_mode: Keyword.get(opts, :mode, :trust),
      rounds_to_win: 2,
      points_per_round: 7,
      logged_at: DateTime.utc_now()
    }
  end

  describe "PlayerActivated" do
    test "creates player_rating row with default 1000" do
      :ok = activate(@p1)
      rating = Repo.get(PlayerRating, @p1)
      assert rating.rating == 1000
      assert rating.games_played == 0
    end
  end

  describe "GameLogged in trust mode (ratings update immediately)" do
    setup do
      Enum.each([@p1, @p2, @p3, @p4], &activate/1)
      :ok
    end

    test "updates ratings on GameLogged in trust mode" do
      :ok = handle(game_logged_event(mode: :trust))

      [p1, p2] = Enum.map([@p1, @p2], &Repo.get(PlayerRating, &1))
      [p3, p4] = Enum.map([@p3, @p4], &Repo.get(PlayerRating, &1))

      assert p1.rating > 1000
      assert p2.rating > 1000
      assert p3.rating < 1000
      assert p4.rating < 1000
    end

    test "does not update ratings on GameLogged in confirmation mode" do
      :ok = handle(game_logged_event(mode: :confirmation))

      Enum.each([@p1, @p2, @p3, @p4], fn pid ->
        assert Repo.get(PlayerRating, pid).rating == 1000
      end)
    end

    test "increments games_played and wins/losses" do
      :ok = handle(game_logged_event(mode: :trust))
      assert Repo.get(PlayerRating, @p1).games_played == 1
      assert Repo.get(PlayerRating, @p1).wins == 1
      assert Repo.get(PlayerRating, @p3).losses == 1
    end
  end

  describe "GameConfirmed (confirmation mode)" do
    setup do
      Enum.each([@p1, @p2, @p3, @p4], &activate/1)
      :ok = handle(game_logged_event(mode: :confirmation))
      # GameConfirmed handler reads from GameRead, so populate it directly
      {:ok, _} = Repo.insert(GameRead.changeset(%{
        id: @game_id, tenant_id: @tenant_id, logged_by: @p1,
        team1_players: [@p1, @p2], team2_players: [@p3, @p4],
        status: "pending", confirmation_mode: "confirmation",
        rounds_to_win: 2, points_per_round: 7,
        logged_at: DateTime.utc_now()
      }))
      :ok
    end

    test "updates ratings on GameConfirmed" do
      :ok = handle(%GameConfirmed.V1{
        game_id: @game_id, tenant_id: @tenant_id,
        confirmed_by: @p3, confirmed_at: DateTime.utc_now()
      })

      assert Repo.get(PlayerRating, @p1).rating > 1000
      assert Repo.get(PlayerRating, @p3).rating < 1000
    end
  end

  describe "PlayerDeleted" do
    setup do: activate(@p1)

    test "marks player as deleted" do
      :ok = handle(%PlayerDeleted.V1{
        player_id: @p1, tenant_id: @tenant_id,
        deleted_by: "admin", deleted_at: DateTime.utc_now()
      })

      assert Repo.get(PlayerRating, @p1).deleted == true
    end
  end
end
