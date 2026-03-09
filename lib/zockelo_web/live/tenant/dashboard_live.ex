defmodule ZockeloWeb.Tenant.DashboardLive do
  @moduledoc "Tenant dashboard: /:tenant_slug/"
  use ZockeloWeb, :live_view

  alias Zockelo.{Games, TeamBalancer, Tenants}

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zockelo.PubSub, "tenant:#{tenant.id}:ratings")
    end

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:current_user, current_user)
     |> assign(:page_title, app_name(tenant))
     |> assign(:balancer_selected, [])
     |> load_data()}
  end

  @impl true
  def handle_info(:ratings_updated, socket) do
    {:noreply, load_data(socket)}
  end

  # ---------------------------------------------------------------------------
  # Team balancer events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("toggle_balancer_player", %{"player_id" => player_id}, socket) do
    selected = socket.assigns.balancer_selected

    new_selected =
      if player_id in selected do
        List.delete(selected, player_id)
      else
        [player_id | selected]
      end

    {:noreply, assign(socket, :balancer_selected, new_selected) |> compute_balancer()}
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-16 sm:pb-0">
      <ZockeloWeb.NavComponent.tenant_nav tenant={@tenant} current_user={@current_user} active="dashboard" />

      <div class="max-w-4xl mx-auto p-4 sm:p-6 space-y-8">
        <!-- Header -->
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold"><%= app_name(@tenant) %></h1>
          <div class="text-sm text-gray-500">
            <%= @stats.player_count %> players · <%= @stats.game_count %> games
          </div>
        </div>

        <!-- Mini leaderboard -->
        <section>
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold text-lg">Leaderboard</h2>
            <.link navigate={~p"/#{@tenant.slug}/leaderboard"} class="text-sm text-blue-600 hover:underline">
              Full leaderboard →
            </.link>
          </div>
          <div class="rounded-lg border bg-white overflow-hidden">
            <%= for {{profile, rating}, idx} <- Enum.with_index(Enum.take(@players, 5)) do %>
              <div class={["flex items-center gap-3 px-4 py-3",
                           if(idx > 0, do: "border-t border-gray-100", else: "")]}>
                <span class="w-6 text-sm font-bold text-gray-400"><%= idx + 1 %></span>
                <div class="flex-1">
                  <.link navigate={~p"/#{@tenant.slug}/players/#{profile.player_id}"}
                         class="font-medium hover:text-blue-600">
                    <%= player_name(profile) %>
                  </.link>
                </div>
                <span class="font-semibold text-sm"><%= rating.rating %></span>
                <span class="text-xs text-gray-400"><%= rating.games_played %>g</span>
                <%= if rating.games_played > 0 do %>
                  <span class={"text-xs font-medium " <> win_rate_class(rating)}>
                    <%= win_rate(rating) %>%
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>
        </section>

        <!-- Current player stats -->
        <% my_rating = Enum.find(@players, fn {p, _} -> p.player_id == @current_user.player_id end) %>
        <%= if my_rating do %>
          <% {_p, r} = my_rating %>
          <section class="rounded-xl bg-blue-50 border border-blue-100 p-4">
            <h2 class="font-semibold mb-2">Your Stats</h2>
            <div class="flex gap-6 text-sm">
              <div><span class="font-bold text-2xl text-blue-600"><%= r.rating %></span><br><span class="text-gray-500">Rating</span></div>
              <div><span class="font-bold text-xl"><%= r.games_played %></span><br><span class="text-gray-500">Games</span></div>
              <div><span class="font-bold text-xl"><%= r.wins %></span><br><span class="text-gray-500">Wins</span></div>
              <div><span class="font-bold text-xl"><%= r.losses %></span><br><span class="text-gray-500">Losses</span></div>
            </div>
          </section>
        <% end %>

        <!-- Pending games -->
        <%= if @pending_games != [] do %>
          <section>
            <h2 class="font-semibold mb-2 text-amber-700">Pending Confirmation (<%= length(@pending_games) %>)</h2>
            <.link navigate={~p"/#{@tenant.slug}/games"} class="text-sm text-blue-600 hover:underline">
              View and confirm →
            </.link>
          </section>
        <% end %>

        <!-- Recent games -->
        <section>
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold text-lg">Recent Games</h2>
            <.link navigate={~p"/#{@tenant.slug}/games"} class="text-sm text-blue-600 hover:underline">
              All games →
            </.link>
          </div>
          <%= if @recent_games == [] do %>
            <p class="text-gray-500 text-sm">No games yet.</p>
          <% else %>
            <div class="space-y-1">
              <%= for game <- @recent_games do %>
                <div class="flex items-center gap-3 text-sm rounded-lg bg-white border px-3 py-2">
                  <span class={"text-xs px-1.5 py-0.5 rounded-full " <> status_class(game.status)}>
                    <%= game.status %>
                  </span>
                  <span class="text-gray-400 text-xs"><%= Calendar.strftime(game.logged_at, "%m/%d") %></span>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>

        <!-- Team balancer -->
        <section class="rounded-xl border bg-white p-4">
          <h2 class="font-semibold mb-3">Team Balancer</h2>
          <p class="text-sm text-gray-500 mb-3">Select 2–4 players to find the fairest split.</p>
          <div class="flex flex-wrap gap-2 mb-4">
            <%= for {profile, _rating} <- @players do %>
              <% selected = profile.player_id in @balancer_selected %>
              <button phx-click="toggle_balancer_player"
                      phx-value-player_id={profile.player_id}
                      class={["rounded-full px-3 py-1 text-sm font-medium border transition",
                              if(selected, do: "bg-blue-600 text-white border-blue-600",
                                          else: "bg-white text-gray-700 border-gray-300 hover:border-blue-400")]}>
                <%= player_name(profile) %>
              </button>
            <% end %>
          </div>

          <%= if @balancer_result do %>
            <% r = @balancer_result %>
            <div class="rounded-lg bg-gray-50 p-3 text-sm space-y-2">
              <p class="font-medium text-gray-700">Suggested split:</p>
              <div class="flex gap-4">
                <div>
                  <p class="text-xs text-gray-500 mb-1">Team 1 (avg <%= round(r.team1_avg) %>)</p>
                  <%= for {p, _} <- r.team1 do %>
                    <p class="font-medium"><%= player_name(p) %></p>
                  <% end %>
                </div>
                <div class="text-gray-400 self-center">vs</div>
                <div>
                  <p class="text-xs text-gray-500 mb-1">Team 2 (avg <%= round(r.team2_avg) %>)</p>
                  <%= for {p, _} <- r.team2 do %>
                    <p class="font-medium"><%= player_name(p) %></p>
                  <% end %>
                </div>
              </div>
              <p class="text-xs text-gray-500">
                Imbalance: <%= round(r.imbalance) %> pts ·
                T1 win probability: <%= round(r.expected_score_team1 * 100) %>%
              </p>
              <.link navigate={balancer_game_url(@tenant.slug, r)}
                     class="inline-block btn btn-primary btn-sm mt-1">
                Log this game →
              </.link>
            </div>
          <% end %>
        </section>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp load_data(socket) do
    tenant = socket.assigns.tenant

    socket
    |> assign(:players, Games.list_active_players_with_ratings(tenant.id))
    |> assign(:recent_games, Games.list_games(tenant.id) |> Enum.take(5))
    |> assign(:pending_games, Games.list_pending_games(tenant.id))
    |> assign(:stats, Tenants.tenant_stats(tenant.id))
    |> compute_balancer()
  end

  defp compute_balancer(socket) do
    selected_ids = socket.assigns.balancer_selected
    all_players = socket.assigns.players

    selected =
      Enum.filter(all_players, fn {p, _} -> p.player_id in selected_ids end)

    result =
      if length(selected) >= 2, do: TeamBalancer.balance(selected), else: nil

    assign(socket, :balancer_result, result)
  end

  defp balancer_game_url(slug, result) do
    t1 = Enum.map(result.team1, fn {p, _} -> p.player_id end) |> Enum.join(",")
    t2 = Enum.map(result.team2, fn {p, _} -> p.player_id end) |> Enum.join(",")
    ~p"/#{slug}/games/new?team1=#{t1}&team2=#{t2}"
  end

  defp player_name(%{encrypted_name: enc, player_id: pid}) when not is_nil(enc) do
    case Zockelo.Crypto.decrypt_field(pid, enc) do
      {:ok, name} -> name
      _ -> Zockelo.Crypto.deleted_player_name()
    end
  end
  defp player_name(%{player_id: pid}), do: "Player #{String.slice(pid, 0, 6)}"

  defp win_rate(%{games_played: 0}), do: 0
  defp win_rate(%{wins: w, games_played: g}), do: round(w / g * 100)

  defp win_rate_class(%{wins: w, games_played: g}) when g > 0 do
    if w / g >= 0.5, do: "text-green-600", else: "text-red-500"
  end
  defp win_rate_class(_), do: "text-gray-400"

  defp status_class("confirmed"), do: "bg-green-100 text-green-700"
  defp status_class("pending"), do: "bg-yellow-100 text-yellow-700"
  defp status_class("disputed"), do: "bg-red-100 text-red-700"
  defp status_class("voided"), do: "bg-gray-100 text-gray-500"
  defp status_class(_), do: "bg-gray-100 text-gray-600"

  defp app_name(%{config: config}) when is_map(config) do
    case Map.get(config, "app_name") do
      nil -> "Zockelo"
      "" -> "Zockelo"
      name -> name
    end
  end
  defp app_name(_), do: "Zockelo"
end
