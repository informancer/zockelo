defmodule ZockeloWeb.Tenant.LeaderboardLive do
  @moduledoc "Live leaderboard: /:tenant_slug/leaderboard"
  use ZockeloWeb, :live_view

  alias Zockelo.Games

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
     |> assign(:page_title, "Leaderboard")
     |> assign(:players, Games.list_active_players_with_ratings(tenant.id))}
  end

  @impl true
  def handle_info(:ratings_updated, socket) do
    {:noreply, assign(socket, :players, Games.list_active_players_with_ratings(socket.assigns.tenant.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-16 sm:pb-0">
      <ZockeloWeb.NavComponent.tenant_nav tenant={@tenant} current_user={@current_user} active="leaderboard" />

      <div class="max-w-2xl mx-auto p-4 sm:p-6">
        <h1 class="text-2xl font-bold mb-6">Leaderboard</h1>

        <%= if @players == [] do %>
          <p class="text-gray-500 text-center py-12">No players yet.</p>
        <% else %>
          <div class="rounded-xl border bg-white overflow-hidden shadow-sm">
            <table class="min-w-full divide-y divide-gray-100">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Player</th>
                  <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Rating</th>
                  <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">W / L</th>
                  <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Games</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <%= for {{profile, rating}, idx} <- Enum.with_index(@players) do %>
                  <tr class={if(profile.player_id == @current_user.player_id, do: "bg-blue-50", else: "")}>
                    <td class="px-4 py-3 text-sm font-semibold text-gray-400"><%= idx + 1 %></td>
                    <td class="px-4 py-3">
                      <.link navigate={~p"/#{@tenant.slug}/players/#{profile.player_id}"}
                             class="font-medium hover:text-blue-600 text-sm">
                        <%= player_name(profile) %>
                        <%= if profile.player_id == @current_user.player_id do %>
                          <span class="ml-1 text-xs text-blue-400">(you)</span>
                        <% end %>
                      </.link>
                    </td>
                    <td class="px-4 py-3 text-right font-bold text-sm"><%= rating.rating %></td>
                    <td class="px-4 py-3 text-right text-sm text-gray-600">
                      <span class="text-green-600"><%= rating.wins %></span>
                      /
                      <span class="text-red-500"><%= rating.losses %></span>
                    </td>
                    <td class="px-4 py-3 text-right text-sm text-gray-500"><%= rating.games_played %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp player_name(%{encrypted_name: enc, player_id: pid}) when not is_nil(enc) do
    case Zockelo.Crypto.decrypt_field(pid, enc) do
      {:ok, name} -> name
      _ -> Zockelo.Crypto.deleted_player_name()
    end
  end
  defp player_name(%{player_id: pid}), do: "Player #{String.slice(pid, 0, 6)}"
end
