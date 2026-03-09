defmodule ZockeloWeb.Tenant.PlayerProfileLive do
  @moduledoc "Player profile: /:tenant_slug/players/:player_id"
  use ZockeloWeb, :live_view

  alias Zockelo.Players
  alias Zockelo.Projections.{PlayerProfile, PlayerRating}
  alias Zockelo.Repo

  @impl true
  def mount(%{"player_id" => player_id}, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user

    profile = Players.get_player(player_id)
    rating = Repo.get(PlayerRating, player_id)

    name = player_display_name(profile)

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:current_user, current_user)
     |> assign(:profile, profile)
     |> assign(:rating, rating || %PlayerRating{rating: 1000, games_played: 0, wins: 0, losses: 0})
     |> assign(:page_title, name)
     |> assign(:player_name, name)
     |> load_game_history(player_id, tenant.id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-16 sm:pb-0">
      <ZockeloWeb.NavComponent.tenant_nav tenant={@tenant} current_user={@current_user} active="profile" />

      <div class="max-w-2xl mx-auto p-4 sm:p-6 space-y-6">
        <!-- Profile header -->
        <div class="flex items-center gap-4">
          <div class="w-16 h-16 rounded-full bg-blue-200 flex items-center justify-center text-2xl font-bold text-blue-700">
            <%= String.first(@player_name) %>
          </div>
          <div>
            <h1 class="text-2xl font-bold"><%= @player_name %></h1>
            <%= if @profile do %>
              <p class="text-sm text-gray-500 capitalize"><%= @profile.role %></p>
            <% end %>
          </div>
          <%= if @current_user.player_id == (if @profile, do: @profile.player_id, else: nil) do %>
            <.link navigate={~p"/#{@tenant.slug}/settings"} class="ml-auto text-sm text-blue-600 hover:underline">
              Edit profile →
            </.link>
          <% end %>
        </div>

        <!-- Stats -->
        <div class="grid grid-cols-4 gap-3">
          <%= for {label, value} <- [{"Rating", @rating.rating}, {"Games", @rating.games_played},
                                     {"Wins", @rating.wins}, {"Losses", @rating.losses}] do %>
            <div class="rounded-xl bg-white border p-3 text-center">
              <p class="text-2xl font-bold"><%= value %></p>
              <p class="text-xs text-gray-500"><%= label %></p>
            </div>
          <% end %>
        </div>

        <!-- Rating chart placeholder -->
        <div class="rounded-xl bg-white border p-4">
          <h2 class="font-semibold mb-3">Rating History</h2>
          <div id="rating-chart"
               phx-hook="RatingChart"
               data-points={Jason.encode!(@chart_points)}
               class="h-48 w-full">
          </div>
        </div>

        <!-- Recent games -->
        <section>
          <h2 class="font-semibold mb-3">Recent Games</h2>
          <%= if @game_history == [] do %>
            <p class="text-gray-500 text-sm">No games yet.</p>
          <% else %>
            <div class="space-y-2">
              <%= for game <- @game_history do %>
                <div class="rounded-lg border bg-white p-3 text-sm flex items-center justify-between">
                  <span class={"text-xs px-2 py-0.5 rounded-full font-medium " <> status_class(game.status)}>
                    <%= game.status %>
                  </span>
                  <span class="text-gray-400 text-xs">
                    <%= Calendar.strftime(game.logged_at, "%Y-%m-%d") %>
                  </span>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    </div>
    """
  end

  defp load_game_history(socket, player_id, tenant_id) do
    import Ecto.Query
    alias Zockelo.Projections.GameRead

    games =
      Repo.all(
        from g in GameRead,
          where:
            g.tenant_id == ^tenant_id and
              (fragment("?::uuid = ANY(?)", ^player_id, g.team1_players) or
                 fragment("?::uuid = ANY(?)", ^player_id, g.team2_players)),
          order_by: [desc: g.logged_at],
          limit: 20
      )

    # Build chart data points from game history (rating deltas)
    chart_points = build_chart_points(games, player_id, tenant_id)

    socket
    |> assign(:game_history, games)
    |> assign(:chart_points, chart_points)
  end

  defp build_chart_points(_games, _player_id, _tenant_id) do
    # Simplified: would join with game_rounds.team1_rating_delta / team2_rating_delta
    # Return empty for now — the hook handles missing data gracefully
    []
  end

  defp player_display_name(nil), do: "[Deleted Player]"
  defp player_display_name(%PlayerProfile{encrypted_name: enc, player_id: pid}) when not is_nil(enc) do
    case Zockelo.Crypto.decrypt_field(pid, enc) do
      {:ok, name} -> name
      _ -> Zockelo.Crypto.deleted_player_name()
    end
  end
  defp player_display_name(%PlayerProfile{player_id: pid}), do: "Player #{String.slice(pid, 0, 6)}"

  defp status_class("confirmed"), do: "bg-green-100 text-green-700"
  defp status_class("pending"), do: "bg-yellow-100 text-yellow-700"
  defp status_class("disputed"), do: "bg-red-100 text-red-700"
  defp status_class("voided"), do: "bg-gray-100 text-gray-500"
  defp status_class(_), do: "bg-gray-100 text-gray-600"
end
