defmodule ZockeloWeb.NavComponent do
  @moduledoc "Shared navigation components for tenant pages."
  use ZockeloWeb, :html

  @doc "Bottom nav bar for mobile / top nav bar for desktop."
  attr :tenant, :map, required: true
  attr :current_user, :map, required: true
  attr :active, :string, default: nil

  def tenant_nav(assigns) do
    ~H"""
    <nav class="fixed bottom-0 left-0 right-0 z-40 bg-white border-t border-gray-200 flex sm:hidden">
      <.nav_item icon="🏆" label="Leaderboard" href={~p"/#{@tenant.slug}/leaderboard"} active={@active == "leaderboard"} />
      <.nav_item icon="🎮" label="Games" href={~p"/#{@tenant.slug}/games"} active={@active == "games"} />
      <.nav_item icon="➕" label="Log" href={~p"/#{@tenant.slug}/games/new"} active={@active == "new_game"} />
      <.nav_item icon="👤" label="Profile" href={~p"/#{@tenant.slug}/players/#{@current_user.player_id}"} active={@active == "profile"} />
    </nav>
    <header class="hidden sm:flex sticky top-0 z-40 bg-white border-b border-gray-200 px-6 py-3 items-center gap-6">
      <.link navigate={~p"/#{@tenant.slug}/"} class="font-bold text-lg text-blue-600 hover:underline mr-4">
        <%= app_name(@tenant) %>
      </.link>
      <.link navigate={~p"/#{@tenant.slug}/leaderboard"} class={nav_link_class(@active == "leaderboard")}>Leaderboard</.link>
      <.link navigate={~p"/#{@tenant.slug}/games"} class={nav_link_class(@active == "games")}>Games</.link>
      <.link navigate={~p"/#{@tenant.slug}/games/new"} class={nav_link_class(@active == "new_game")}>Log Game</.link>
      <div class="flex-1"></div>
      <%= if @current_user.role in ["tenant_admin", "super_admin"] do %>
        <.link navigate={~p"/#{@tenant.slug}/admin"} class="text-sm text-gray-500 hover:text-gray-700">Admin</.link>
      <% end %>
      <.link navigate={~p"/#{@tenant.slug}/settings"} class="text-sm text-gray-500 hover:text-gray-700">Settings</.link>
    </header>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :href, :string, required: true
  attr :active, :boolean, default: false

  defp nav_item(assigns) do
    ~H"""
    <.link navigate={@href} class={["flex-1 flex flex-col items-center justify-center py-2 text-xs gap-0.5 transition",
                                    if(@active, do: "text-blue-600", else: "text-gray-500")]}>
      <span class="text-lg leading-none"><%= @icon %></span>
      <%= @label %>
    </.link>
    """
  end

  defp nav_link_class(active) do
    base = "text-sm font-medium transition"
    if active, do: base <> " text-blue-600 underline", else: base <> " text-gray-600 hover:text-gray-900"
  end

  defp app_name(%{config: config}) when is_map(config) do
    Map.get(config, "app_name") |> case do
      nil -> "Zockelo"
      "" -> "Zockelo"
      name -> name
    end
  end
  defp app_name(_), do: "Zockelo"
end
