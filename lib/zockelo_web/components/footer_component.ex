defmodule ZockeloWeb.FooterComponent do
  @moduledoc "Footer with imprint and privacy links, shown on all pages."
  use ZockeloWeb, :html

  def footer(assigns) do
    ~H"""
    <footer class="mt-auto py-4 px-6 text-center text-xs text-gray-400 space-x-4">
      <%= if assigns[:tenant] do %>
        <.link navigate={~p"/#{@tenant.slug}/imprint"} class="hover:underline">Imprint</.link>
        <.link navigate={~p"/#{@tenant.slug}/privacy"} class="hover:underline">Privacy Notice</.link>
      <% end %>
    </footer>
    """
  end
end
