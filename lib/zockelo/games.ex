defmodule Zockelo.Games do
  @moduledoc """
  Context for game logging, confirmation flow, and retrieval.
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.CommandedApp
  alias Zockelo.Projections.{GameRead, GameRound, PlayerProfile, PlayerRating}
  alias Zockelo.Workers.GameNotificationWorker

  alias Zockelo.Domain.Commands.{
    LogGame,
    ConfirmGame,
    DisputeGame,
    ReinstateGame,
    VoidGame
  }

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
    mode = parse_mode(attrs.confirmation_mode)

    cmd = %LogGame{
      game_id: game_id,
      tenant_id: attrs.tenant_id,
      logged_by: attrs.logged_by,
      team1_players: attrs.team1_players,
      team2_players: attrs.team2_players,
      rounds: normalize_rounds(attrs.rounds),
      confirmation_mode: mode,
      rounds_to_win: attrs.rounds_to_win,
      points_per_round: attrs.points_per_round
    }

    case CommandedApp.dispatch(cmd) do
      :ok ->
        # Dual-write for synchronous read consistency.
        # GameHistoryProjection handles async event replay (idempotent upsert).
        initial_status = if mode == :trust, do: "confirmed", else: "pending"

        Repo.insert(
          %GameRead{
            id: game_id,
            tenant_id: attrs.tenant_id,
            logged_by: attrs.logged_by,
            team1_players: attrs.team1_players,
            team2_players: attrs.team2_players,
            status: initial_status,
            confirmation_mode: to_string(mode),
            rounds_to_win: attrs.rounds_to_win,
            points_per_round: attrs.points_per_round,
            logged_at: DateTime.utc_now()
          },
          on_conflict: :nothing,
          conflict_target: :id
        )

        enqueue_game_notification("game_logged", game_id, attrs.tenant_id,
          attrs.team1_players ++ attrs.team2_players)

        {:ok, game_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Confirmation flow
  # ---------------------------------------------------------------------------

  @doc "Confirms a pending game. Returns :ok or {:error, reason}."
  def confirm_game(game_id, confirmed_by) do
    with %GameRead{tenant_id: tid, team1_players: t1, team2_players: t2, status: "pending"} <-
           Repo.get(GameRead, game_id) do
      case CommandedApp.dispatch(%ConfirmGame{
             game_id: game_id,
             tenant_id: tid,
             confirmed_by: confirmed_by
           }) do
        :ok ->
          enqueue_game_notification("game_confirmed", game_id, tid, (t1 || []) ++ (t2 || []))
          :ok

        err ->
          err
      end
    else
      nil -> {:error, :not_found}
      %GameRead{} -> {:error, :invalid_status}
    end
  end

  @doc "Disputes a pending game. Returns :ok or {:error, reason}."
  def dispute_game(game_id, disputed_by, reason \\ nil) do
    with %GameRead{tenant_id: tid, team1_players: t1, team2_players: t2, status: "pending"} <-
           Repo.get(GameRead, game_id) do
      case CommandedApp.dispatch(%DisputeGame{
             game_id: game_id,
             tenant_id: tid,
             disputed_by: disputed_by,
             reason: reason
           }) do
        :ok ->
          enqueue_game_notification("game_disputed", game_id, tid, (t1 || []) ++ (t2 || []))
          :ok

        err ->
          err
      end
    else
      nil -> {:error, :not_found}
      %GameRead{} -> {:error, :invalid_status}
    end
  end

  @doc "Reinstates a disputed game (tenant admin only). Returns :ok or {:error, reason}."
  def reinstate_game(game_id, reinstated_by) do
    with %GameRead{tenant_id: tid, status: "disputed"} <- Repo.get(GameRead, game_id) do
      case CommandedApp.dispatch(%ReinstateGame{
             game_id: game_id,
             tenant_id: tid,
             reinstated_by: reinstated_by
           }) do
        :ok -> :ok
        err -> err
      end
    else
      nil -> {:error, :not_found}
      %GameRead{} -> {:error, :invalid_status}
    end
  end

  @doc "Voids a pending or disputed game. Returns :ok or {:error, reason}."
  def void_game(game_id, voided_by) do
    with %GameRead{tenant_id: tid, status: s} when s in ["pending", "disputed"] <-
           Repo.get(GameRead, game_id) do
      case CommandedApp.dispatch(%VoidGame{
             game_id: game_id,
             tenant_id: tid,
             voided_by: voided_by
           }) do
        :ok -> :ok
        err -> err
      end
    else
      nil -> {:error, :not_found}
      %GameRead{} -> {:error, :invalid_status}
    end
  end

  @doc """
  Voids all pending and disputed games that include `player_id`.
  Used during player deletion to clean up incomplete games.
  """
  def void_player_games(player_id, tenant_id, voided_by) do
    games =
      Repo.all(
        from g in GameRead,
          where:
            g.tenant_id == ^tenant_id and
              g.status in ["pending", "disputed"] and
              (fragment("? = ANY(?)", type(^player_id, :binary_id), g.team1_players) or
                 fragment("? = ANY(?)", type(^player_id, :binary_id), g.team2_players))
      )

    Enum.each(games, fn game ->
      CommandedApp.dispatch(%VoidGame{
        game_id: game.id,
        tenant_id: tenant_id,
        voided_by: voided_by
      })
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc """
  Returns `[{PlayerProfile, PlayerRating}]` for all active players in a tenant,
  sorted by rating DESC, games_played DESC, name ASC.
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
      |> Map.new(&{&1.player_id, &1})

    profiles
    |> Enum.map(fn p ->
      rating =
        Map.get(ratings_map, p.player_id, %PlayerRating{
          player_id: p.player_id,
          tenant_id: tenant_id,
          rating: 1000,
          games_played: 0,
          wins: 0,
          losses: 0
        })

      {p, rating}
    end)
    |> Enum.sort_by(fn {p, r} ->
      name =
        if p.encrypted_name do
          case Zockelo.Crypto.decrypt_field(p.player_id, p.encrypted_name) do
            {:ok, n} -> n
            _ -> ""
          end
        else
          ""
        end

      {-r.rating, -r.games_played, name}
    end)
  end

  @doc "Returns all GameRead rows for a tenant, newest first."
  def list_games(tenant_id) do
    Repo.all(
      from g in GameRead,
        where: g.tenant_id == ^tenant_id,
        order_by: [desc: g.logged_at]
    )
  end

  @page_size 20

  @doc """
  Returns a page of games for a tenant, with optional filters.

  Options:
    - `:player_id` — UUID string; only games where the player is a participant
    - `:date_from` — `Date` or `nil`; filter games logged on or after this date
    - `:date_to`   — `Date` or `nil`; filter games logged on or before this date
    - `:page`      — 0-based page index (default 0)
  """
  def list_games_page(tenant_id, opts \\ []) do
    player_id = Keyword.get(opts, :player_id)
    date_from = Keyword.get(opts, :date_from)
    date_to = Keyword.get(opts, :date_to)
    page = max(Keyword.get(opts, :page, 0), 0)

    base =
      from g in GameRead,
        where: g.tenant_id == ^tenant_id,
        order_by: [desc: g.logged_at]

    base =
      if player_id do
        from g in base,
          where:
            fragment("? = ANY(?)", type(^player_id, :binary_id), g.team1_players) or
              fragment("? = ANY(?)", type(^player_id, :binary_id), g.team2_players)
      else
        base
      end

    base =
      if date_from do
        from g in base, where: g.logged_at >= ^DateTime.new!(date_from, ~T[00:00:00])
      else
        base
      end

    base =
      if date_to do
        from g in base, where: g.logged_at <= ^DateTime.new!(date_to, ~T[23:59:59])
      else
        base
      end

    total = Repo.aggregate(base, :count)

    games =
      Repo.all(
        from g in base,
          limit: ^@page_size,
          offset: ^(page * @page_size)
      )

    %{games: games, page: page, page_size: @page_size, total: total}
  end

  @doc "Returns pending GameRead rows for a tenant, oldest first."
  def list_pending_games(tenant_id) do
    Repo.all(
      from g in GameRead,
        where: g.tenant_id == ^tenant_id and g.status == "pending",
        order_by: [asc: g.logged_at]
    )
  end

  @doc "Returns disputed GameRead rows for a tenant, oldest first."
  def list_disputed_games(tenant_id) do
    Repo.all(
      from g in GameRead,
        where: g.tenant_id == ^tenant_id and g.status == "disputed",
        order_by: [asc: g.logged_at]
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

  defp enqueue_game_notification(event_type, game_id, tenant_id, player_ids) do
    trigger_id = "#{event_type}:#{game_id}"

    %{
      event_type: event_type,
      game_id: game_id,
      tenant_id: tenant_id,
      player_ids: player_ids,
      trigger_id: trigger_id
    }
    |> GameNotificationWorker.new()
    |> Oban.insert()

    :ok
  end
end
