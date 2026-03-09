defmodule ZockeloWeb.Tenant.GamesLive do
  @moduledoc "Game history for a tenant: /:tenant_slug/games"
  use ZockeloWeb, :live_view

  alias Zockelo.Games

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    games = Games.list_games(tenant.id)

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:games, games)
     |> assign(:page_title, "Games")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4 space-y-4">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Games</h1>
        <.link navigate={~p"/#{@tenant.slug}/games/new"}
               class="btn btn-primary btn-sm">Log a Game</.link>
      </div>

      <%= if @games == [] do %>
        <div class="text-center py-12 text-gray-500">
          <p class="text-lg">No games logged yet.</p>
          <.link navigate={~p"/#{@tenant.slug}/games/new"} class="text-blue-600 hover:underline mt-2 inline-block">
            Log your first game →
          </.link>
        </div>
      <% else %>
        <div class="space-y-2">
          <%= for game <- @games do %>
            <div class="rounded-lg border bg-white p-4 shadow-sm">
              <div class="flex items-center justify-between">
                <span class={"text-xs font-medium px-2 py-0.5 rounded-full #{status_class(game.status)}"}>
                  <%= game.status %>
                </span>
                <span class="text-xs text-gray-400" data-timestamp={game.logged_at}>
                  <%= Calendar.strftime(game.logged_at, "%Y-%m-%d") %>
                </span>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_class("confirmed"), do: "bg-green-100 text-green-700"
  defp status_class("pending"), do: "bg-yellow-100 text-yellow-700"
  defp status_class("disputed"), do: "bg-red-100 text-red-700"
  defp status_class("voided"), do: "bg-gray-100 text-gray-500"
  defp status_class(_), do: "bg-gray-100 text-gray-600"
end
