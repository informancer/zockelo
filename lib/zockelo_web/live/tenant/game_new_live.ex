defmodule ZockeloWeb.Tenant.GameNewLive do
  @moduledoc """
  Game logging LiveView: /:tenant_slug/games/new

  Supports 2v2 (front/back positions) and 1v1 (single slot per side).
  """
  use ZockeloWeb, :live_view

  alias Zockelo.Games
  alias Zockelo.Projections.PlayerProfile

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    config = tenant.config || %{}
    rounds_to_win = config["rounds_to_win"] || 2
    points_per_round = config["points_per_round"] || 7
    confirmation_mode = config["confirmation_mode"] || "trust"

    players = Games.list_active_players_with_ratings(tenant.id)
    mode = if length(players) <= 2, do: :one_v_one, else: :two_v_two

    initial_slots = initial_slots(mode, players)
    initial_rounds = [empty_round()]

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:rounds_to_win, rounds_to_win)
     |> assign(:points_per_round, points_per_round)
     |> assign(:confirmation_mode, confirmation_mode)
     |> assign(:mode, mode)
     |> assign(:players, players)
     |> assign(:slots, initial_slots)
     |> assign(:rounds, initial_rounds)
     |> assign(:picker_open, nil)
     |> assign(:picker_search, "")
     |> assign(:submit_error, nil)
     |> assign(:page_title, "Log a Game")}
  end

  # ---------------------------------------------------------------------------
  # Slot / picker events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("open_picker", %{"slot" => slot}, socket) do
    {:noreply, socket |> assign(:picker_open, String.to_existing_atom(slot)) |> assign(:picker_search, "")}
  end

  def handle_event("close_picker", _params, socket) do
    {:noreply, assign(socket, :picker_open, nil)}
  end

  def handle_event("search_picker", %{"q" => q}, socket) do
    {:noreply, assign(socket, :picker_search, q)}
  end

  def handle_event("assign_player", %{"player_id" => player_id}, socket) do
    slot = socket.assigns.picker_open
    old_slots = socket.assigns.slots

    # If this player was already in another slot, clear that slot first
    new_slots =
      old_slots
      |> Enum.map(fn {k, v} -> {k, if(v == player_id and k != slot, do: nil, else: v)} end)
      |> Enum.into(%{})
      |> Map.put(slot, player_id)

    {:noreply,
     socket
     |> assign(:slots, new_slots)
     |> assign(:picker_open, nil)}
  end

  def handle_event("clear_slot", %{"slot" => slot}, socket) do
    new_slots = Map.put(socket.assigns.slots, String.to_existing_atom(slot), nil)
    {:noreply, assign(socket, :slots, new_slots)}
  end

  # ---------------------------------------------------------------------------
  # Round events
  # ---------------------------------------------------------------------------

  def handle_event("update_score", %{"round" => round_str, "team" => team, "score" => score_str}, socket) do
    round_idx = String.to_integer(round_str)
    score = parse_score(score_str)

    new_rounds =
      socket.assigns.rounds
      |> List.update_at(round_idx, fn r ->
        key = if team == "1", do: :team1_score, else: :team2_score
        %{r | key => score}
      end)

    {:noreply, socket |> assign(:rounds, new_rounds) |> maybe_add_round()}
  end

  def handle_event("remove_round", %{"round" => round_str}, socket) do
    idx = String.to_integer(round_str)
    new_rounds = List.delete_at(socket.assigns.rounds, idx)
    new_rounds = if new_rounds == [], do: [empty_round()], else: new_rounds
    {:noreply, assign(socket, :rounds, new_rounds)}
  end

  # ---------------------------------------------------------------------------
  # Submit
  # ---------------------------------------------------------------------------

  def handle_event("submit", _params, socket) do
    %{slots: slots, rounds: rounds, mode: mode,
      tenant: tenant, rounds_to_win: rtw, points_per_round: ppr,
      confirmation_mode: conf_mode} = socket.assigns

    logged_by = socket.assigns.current_session.player_id

    {team1, team2} = teams_from_slots(slots, mode)

    rounds_with_positions = rounds_with_positions(rounds, slots, mode)

    result = Games.log_game(%{
      tenant_id: tenant.id,
      logged_by: logged_by,
      team1_players: team1,
      team2_players: team2,
      rounds: rounds_with_positions,
      confirmation_mode: conf_mode,
      rounds_to_win: rtw,
      points_per_round: ppr
    })

    case result do
      {:ok, _game_id} ->
        flash_msg =
          if conf_mode == "trust" do
            "Game logged — ratings updated!"
          else
            "Game logged — waiting for confirmation."
          end

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> push_navigate(to: ~p"/#{tenant.slug}/games")}

      {:error, reason} ->
        {:noreply, assign(socket, :submit_error, error_message(reason))}
    end
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4 space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Log a Game</h1>
        <.link navigate={~p"/#{@tenant.slug}/games"} class="text-sm text-blue-600 hover:underline">← Games</.link>
      </div>

      <%= if @submit_error do %>
        <div class="rounded-lg bg-red-50 border border-red-200 p-3 text-sm text-red-700">
          <%= @submit_error %>
        </div>
      <% end %>

      <!-- Foosball table -->
      <div class="rounded-2xl bg-green-700 p-4 shadow-inner">
        <div class="flex items-stretch gap-2">
          <!-- Team 1 -->
          <div class="flex-1 space-y-2">
            <p class="text-white text-xs font-semibold text-center mb-1 uppercase tracking-wide">Team 1</p>
            <%= if @mode == :two_v_two do %>
              <%= slot_button(assigns, :team1_front, "Front") %>
              <%= slot_button(assigns, :team1_back, "Back") %>
            <% else %>
              <%= slot_button(assigns, :team1, "") %>
            <% end %>
          </div>

          <!-- Centre net -->
          <div class="flex items-center justify-center w-8">
            <div class="h-full w-0.5 bg-white/30 mx-auto"></div>
          </div>

          <!-- Team 2 -->
          <div class="flex-1 space-y-2">
            <p class="text-white text-xs font-semibold text-center mb-1 uppercase tracking-wide">Team 2</p>
            <%= if @mode == :two_v_two do %>
              <%= slot_button(assigns, :team2_front, "Front") %>
              <%= slot_button(assigns, :team2_back, "Back") %>
            <% else %>
              <%= slot_button(assigns, :team2, "") %>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Rounds -->
      <div>
        <h2 class="font-semibold mb-2">Rounds</h2>
        <div class="space-y-2">
          <%= for {round, idx} <- Enum.with_index(@rounds) do %>
            <div class="flex items-center gap-3 rounded-lg bg-gray-50 p-3">
              <span class="text-sm text-gray-500 w-16">Round <%= idx + 1 %></span>
              <div class="flex items-center gap-2 flex-1">
                <input type="number" min="0" max={@points_per_round}
                       value={round.team1_score}
                       phx-change="update_score"
                       phx-value-round={idx}
                       phx-value-team="1"
                       name={"rounds[#{idx}][team1_score]"}
                       class="input input-sm input-bordered w-16 text-center"
                       placeholder="0" />
                <span class="text-gray-400">:</span>
                <input type="number" min="0" max={@points_per_round}
                       value={round.team2_score}
                       phx-change="update_score"
                       phx-value-round={idx}
                       phx-value-team="2"
                       name={"rounds[#{idx}][team2_score]"}
                       class="input input-sm input-bordered w-16 text-center"
                       placeholder="0" />
                <%= round_winner_badge(round) %>
              </div>
              <%= if length(@rounds) > 1 do %>
                <button phx-click="remove_round" phx-value-round={idx}
                        class="text-gray-400 hover:text-red-500 text-xs">✕</button>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Win progress -->
        <div class="mt-3 flex gap-4 text-sm">
          <% {w1, w2} = count_wins(@rounds) %>
          <span class={"font-medium #{if w1 >= @rounds_to_win, do: "text-green-600", else: "text-gray-600"}"}>
            Team 1: <%= w1 %> / <%= @rounds_to_win %> wins
          </span>
          <span class={"font-medium #{if w2 >= @rounds_to_win, do: "text-green-600", else: "text-gray-600"}"}>
            Team 2: <%= w2 %> / <%= @rounds_to_win %> wins
          </span>
        </div>

        <%= unless winner_reached?(@rounds, @rounds_to_win) do %>
          <p class="text-xs text-amber-600 mt-1">Keep entering rounds until a team wins.</p>
        <% end %>
      </div>

      <!-- Submit -->
      <div>
        <button phx-click="submit"
                disabled={not can_submit?(@slots, @rounds, @rounds_to_win, @mode)}
                class="btn btn-primary w-full disabled:opacity-50">
          Log Game
        </button>
      </div>
    </div>

    <!-- Player picker overlay — focus trap: focus enters search input on open; Escape closes -->
    <%= if @picker_open do %>
      <div
        class="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center p-4"
        phx-click="close_picker"
        phx-key="Escape"
        phx-window-keydown="close_picker"
        role="dialog"
        aria-modal="true"
        aria-label="Pick a player"
      >
        <div class="bg-white rounded-2xl w-full max-w-sm max-h-[70vh] flex flex-col shadow-2xl"
             phx-click-away="close_picker"
             id="picker-overlay">
          <div class="p-4 border-b">
            <input type="text" placeholder="Search players…"
                   phx-keyup="search_picker" phx-value-q=""
                   name="picker_search"
                   value={@picker_search}
                   class="input input-bordered w-full"
                   autofocus
                   aria-label="Search players" />
          </div>
          <div class="overflow-y-auto flex-1 p-2 space-y-1">
            <%= for {profile, rating} <- filtered_players(@players, @picker_search) do %>
              <% assigned = Map.values(@slots) |> Enum.filter(& &1) %>
              <% is_taken = profile.player_id in assigned and Map.get(@slots, @picker_open) != profile.player_id %>
              <button phx-click="assign_player"
                      phx-value-player_id={profile.player_id}
                      disabled={is_taken}
                      class={[
                        "w-full flex items-center gap-3 rounded-lg px-3 py-2 text-left transition",
                        if(is_taken, do: "opacity-40 cursor-not-allowed bg-gray-50",
                                    else: "hover:bg-blue-50 active:bg-blue-100")
                      ]}>
                <div class="w-9 h-9 rounded-full bg-blue-200 flex items-center justify-center text-sm font-bold text-blue-700">
                  <%= String.first(display_name(profile)) %>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-sm truncate"><%= display_name(profile) %></p>
                  <p class="text-xs text-gray-500"><%= rating.rating %> pts · <%= rating.games_played %> games</p>
                </div>
                <%= if Map.get(@slots, @picker_open) == profile.player_id do %>
                  <span class="text-blue-500 text-xs">✓</span>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Private components
  # ---------------------------------------------------------------------------

  defp slot_button(assigns, slot, label) do
    player_id = Map.get(assigns.slots, slot)
    player_info = player_id && find_player(assigns.players, player_id)

    assigns =
      assigns
      |> assign(:slot, slot)
      |> assign(:slot_label, label)
      |> assign(:player_id, player_id)
      |> assign(:player_info, player_info)

    ~H"""
    <div class="relative">
      <button
        phx-click="open_picker"
        phx-value-slot={@slot}
        tabindex="0"
        aria-label={if @player_info do
          {profile, rating} = @player_info
          "#{@slot_label} — #{display_name(profile)}, rating #{rating.rating}. Press Enter to change."
        else
          "#{@slot_label} — Empty. Press Enter to pick a player."
        end}
        class="w-full rounded-xl bg-white/20 hover:bg-white/30 text-white p-3 text-left transition min-h-[60px] flex items-center gap-2 focus-visible:outline-2 focus-visible:outline-white focus-visible:outline-offset-2"
      >
        <%= if @player_info do %>
          <% {profile, rating} = @player_info %>
          <div class="w-8 h-8 rounded-full bg-white/80 flex items-center justify-center text-xs font-bold text-green-800" aria-hidden="true">
            <%= String.first(display_name(profile)) %>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-xs font-semibold truncate"><%= display_name(profile) %></p>
            <p class="text-xs text-white/70"><%= rating.rating %></p>
          </div>
        <% else %>
          <div class="w-8 h-8 rounded-full border-2 border-dashed border-white/50 flex items-center justify-center text-white/50 text-sm" aria-hidden="true">+</div>
          <span class="text-white/60 text-xs"><%= if @slot_label != "", do: @slot_label, else: "Tap to pick" %></span>
        <% end %>
      </button>
      <%= if @player_id do %>
        <button phx-click="clear_slot" phx-value-slot={@slot}
                class="absolute top-1 right-1 text-white/40 hover:text-white text-xs leading-none">✕</button>
      <% end %>
    </div>
    """
  end

  defp round_winner_badge(assigns) do
    cond do
      assigns.team1_score > assigns.team2_score ->
        ~H|<span class="text-xs text-green-600 font-medium ml-1">T1 ✓</span>|
      assigns.team2_score > assigns.team1_score ->
        ~H|<span class="text-xs text-green-600 font-medium ml-1">T2 ✓</span>|
      true ->
        ~H|<span></span>|
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp initial_slots(:one_v_one, players) do
    [p1, p2 | _] = Enum.map(players, fn {p, _} -> p.player_id end) ++ [nil, nil]
    %{team1: p1, team2: p2}
  end

  defp initial_slots(:two_v_two, players) when length(players) <= 2 do
    [p1, p2 | _] = Enum.map(players, fn {p, _} -> p.player_id end) ++ [nil, nil]
    %{team1_front: p1, team1_back: nil, team2_front: p2, team2_back: nil}
  end

  defp initial_slots(:two_v_two, _players) do
    %{team1_front: nil, team1_back: nil, team2_front: nil, team2_back: nil}
  end

  defp empty_round, do: %{team1_score: nil, team2_score: nil}

  defp maybe_add_round(socket) do
    rounds = socket.assigns.rounds
    rounds_to_win = socket.assigns.rounds_to_win
    {w1, w2} = count_wins(rounds)

    if w1 >= rounds_to_win or w2 >= rounds_to_win do
      # Game is over — don't add more rounds
      socket
    else
      last = List.last(rounds)

      if last.team1_score != nil and last.team2_score != nil do
        assign(socket, :rounds, rounds ++ [empty_round()])
      else
        socket
      end
    end
  end

  defp count_wins(rounds) do
    w1 = Enum.count(rounds, fn r ->
      r.team1_score != nil and r.team2_score != nil and r.team1_score > r.team2_score
    end)
    w2 = Enum.count(rounds, fn r ->
      r.team1_score != nil and r.team2_score != nil and r.team2_score > r.team1_score
    end)
    {w1, w2}
  end

  defp winner_reached?(rounds, rounds_to_win) do
    {w1, w2} = count_wins(rounds)
    w1 >= rounds_to_win or w2 >= rounds_to_win
  end

  defp can_submit?(slots, rounds, rounds_to_win, mode) do
    # All required slots filled
    required_filled =
      case mode do
        :one_v_one -> slots[:team1] != nil and slots[:team2] != nil
        :two_v_two -> slots[:team1_front] != nil and slots[:team2_front] != nil
      end

    required_filled and winner_reached?(rounds, rounds_to_win)
  end

  defp teams_from_slots(slots, :one_v_one) do
    {[slots[:team1]], [slots[:team2]]}
  end

  defp teams_from_slots(slots, :two_v_two) do
    team1 = [slots[:team1_front], slots[:team1_back]] |> Enum.reject(&is_nil/1)
    team2 = [slots[:team2_front], slots[:team2_back]] |> Enum.reject(&is_nil/1)
    {team1, team2}
  end

  defp rounds_with_positions(rounds, slots, :one_v_one) do
    Enum.map(rounds, fn r ->
      Map.merge(r, %{
        team1_front: slots[:team1],
        team1_back: nil,
        team2_front: slots[:team2],
        team2_back: nil
      })
    end)
  end

  defp rounds_with_positions(rounds, slots, :two_v_two) do
    Enum.map(rounds, fn r ->
      Map.merge(r, %{
        team1_front: slots[:team1_front],
        team1_back: slots[:team1_back],
        team2_front: slots[:team2_front],
        team2_back: slots[:team2_back]
      })
    end)
  end

  defp filtered_players(players, ""), do: players

  defp filtered_players(players, search) do
    q = String.downcase(search)

    Enum.filter(players, fn {profile, _rating} ->
      String.contains?(String.downcase(display_name(profile)), q)
    end)
  end

  defp find_player(players, player_id) do
    Enum.find(players, fn {p, _} -> p.player_id == player_id end)
  end

  defp display_name(%PlayerProfile{encrypted_name: enc, player_id: pid}) when not is_nil(enc) do
    case Zockelo.Crypto.decrypt_field(pid, enc) do
      {:ok, name} -> name
      _ -> "Player #{String.slice(pid, 0, 6)}"
    end
  end

  defp display_name(%PlayerProfile{player_id: pid}),
    do: "Player #{String.slice(pid, 0, 6)}"

  defp parse_score(nil), do: nil
  defp parse_score(""), do: nil
  defp parse_score(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp error_message(:duplicate_player), do: "A player cannot appear on both teams."
  defp error_message(:score_exceeds_limit), do: "A score exceeds the maximum points per round."
  defp error_message(:no_winner), do: "No team has won the required number of rounds."
  defp error_message(other), do: "Error: #{inspect(other)}"
end
