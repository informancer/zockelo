defmodule ZockeloWeb.MaintenanceBanner do
  @moduledoc """
  Maintenance announcement banner shown on all pages when a maintenance message is set.

  Dismissable per-session via localStorage. Reappears if the message changes.
  Rendered from the root layout so it appears on every page.
  """
  use ZockeloWeb, :html

  @doc """
  Renders the maintenance banner if a message is set.

  Expects assigns:
    - :maintenance_message — string or nil
    - :maintenance_scheduled_at — ISO 8601 string or nil
  """
  def maintenance_banner(assigns) do
    ~H"""
    <%= if @maintenance_message && @maintenance_message != "" do %>
      <div
        id="maintenance-banner"
        data-message-key={"maintenance-banner-dismissed-#{:crypto.hash(:md5, @maintenance_message) |> Base.encode16(case: :lower)}"}
        class="hidden bg-yellow-50 border-b border-yellow-300 px-4 py-3"
        role="alert"
        aria-live="polite"
      >
        <div class="max-w-4xl mx-auto flex items-start justify-between gap-4">
          <div class="flex-1 text-sm text-yellow-800">
            <span class="font-semibold">Scheduled Maintenance: </span>
            <%= @maintenance_message %>
            <%= if @maintenance_scheduled_at && @maintenance_scheduled_at != "" do %>
              <span class="ml-2 text-yellow-600">
                (<span id="maintenance-scheduled-at" data-timestamp={@maintenance_scheduled_at} phx-hook="LocalTime"><%= @maintenance_scheduled_at %></span>)
              </span>
            <% end %>
          </div>
          <button
            type="button"
            onclick="document.getElementById('maintenance-banner').dataset.dismiss='true'; window.__dismissMaintenanceBanner && window.__dismissMaintenanceBanner();"
            class="shrink-0 text-yellow-600 hover:text-yellow-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-yellow-600 rounded"
            aria-label="Dismiss maintenance notice"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    <% end %>
    """
  end
end
