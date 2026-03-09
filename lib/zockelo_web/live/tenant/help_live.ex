defmodule ZockeloWeb.Tenant.HelpLive do
  @moduledoc "In-app help page: /:tenant_slug/help"
  use ZockeloWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user
    config = tenant.config || %{}

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:current_user, current_user)
     |> assign(:page_title, "Help")
     |> assign(:confirmation_mode, Map.get(config, "confirmation_mode", "trust"))
     |> assign(:rounds_to_win, Map.get(config, "rounds_to_win", 2))
     |> assign(:points_per_round, Map.get(config, "points_per_round", 10))
     |> assign(:auto_confirm_hours, Map.get(config, "auto_confirm_after_hours", 24))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-16 sm:pb-0">
      <ZockeloWeb.NavComponent.tenant_nav tenant={@tenant} current_user={@current_user} active="help" />

      <div class="max-w-2xl mx-auto p-4 sm:p-6 space-y-8">
        <h1 class="text-2xl font-bold">Help</h1>

        <!-- How games work -->
        <section class="space-y-3">
          <h2 class="text-lg font-semibold">How games work</h2>
          <div class="rounded-xl border bg-white p-4 text-sm text-gray-700 space-y-2">
            <p>Games are played as 1v1, 2v1, or 2v2.</p>
            <p>
              A match consists of rounds. First team to win
              <strong><%= @rounds_to_win %></strong>
              rounds wins the match.
              Each round is played to <strong><%= @points_per_round %></strong> points.
            </p>
          </div>
        </section>

        <!-- Confirmation mode -->
        <section class="space-y-3">
          <h2 class="text-lg font-semibold">
            Game confirmation
            <.tooltip id="tooltip-confirmation" text="Confirmation mode controls when ratings are updated after a game is logged.">
              <span class="cursor-help text-gray-400 text-sm">(?)</span>
            </.tooltip>
          </h2>
          <div class="rounded-xl border bg-white p-4 text-sm text-gray-700 space-y-2">
            <%= if @confirmation_mode == "trust" do %>
              <p>
                This league uses <strong>trust mode</strong>: ratings update immediately
                when a game is logged, no confirmation needed.
              </p>
            <% else %>
              <p>
                This league uses <strong>confirmation mode</strong>: participants must confirm
                a game before ratings update.
              </p>
              <p>
                If no one disputes the result within
                <strong><%= @auto_confirm_hours %> hours</strong>,
                the game is auto-confirmed.
              </p>
              <p>
                Any participant or league admin can dispute a game. Disputed games are
                reviewed by a league admin who can reinstate or void the result.
              </p>
            <% end %>
          </div>
        </section>

        <!-- Elo rating -->
        <section class="space-y-3">
          <h2 class="text-lg font-semibold">
            Elo rating
            <.tooltip id="tooltip-elo" text="Elo is a method for calculating relative skill levels. Your rating goes up when you beat higher-rated opponents and down when you lose to lower-rated ones.">
              <span class="cursor-help text-gray-400 text-sm">(?)</span>
            </.tooltip>
          </h2>
          <div class="rounded-xl border bg-white p-4 text-sm text-gray-700 space-y-2">
            <p>
              Everyone starts at <strong>1000</strong>. Winning gains points, losing loses points.
              The amount depends on the rating difference between teams.
            </p>
            <p>
              The K-factor controls how quickly ratings change:
            </p>
            <ul class="list-disc list-inside space-y-1 text-gray-600">
              <li>Rating &lt; 1400 → K = 40 (high volatility, new players settle quickly)</li>
              <li>Rating 1400–1800 → K = 32</li>
              <li>Rating &gt; 1800 → K = 20 (stable top ratings)</li>
            </ul>
            <p>For team games, team ratings are averaged before calculating the expected outcome.</p>
          </div>
        </section>

        <!-- Team balancer -->
        <section class="space-y-3">
          <h2 class="text-lg font-semibold">
            Team balancer
            <.tooltip id="tooltip-balancer" text="The team balancer tries all possible splits and picks the one with the smallest rating gap between teams.">
              <span class="cursor-help text-gray-400 text-sm">(?)</span>
            </.tooltip>
          </h2>
          <div class="rounded-xl border bg-white p-4 text-sm text-gray-700 space-y-2">
            <p>
              Select 2–4 players on the dashboard and the balancer will suggest the fairest
              split based on current Elo ratings.
            </p>
            <p>
              It evaluates every possible team combination and picks the one that minimises
              the rating difference between teams. The win probability for each team is
              shown alongside the suggestion.
            </p>
          </div>
        </section>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Tooltip functional component (12.2)
  # ---------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :text, :string, required: true
  slot :inner_block, required: true

  defp tooltip(assigns) do
    ~H"""
    <span class="group relative inline-block" id={@id} phx-hook="Tooltip">
      <span tabindex="0" aria-describedby={"#{@id}-content"}>
        <%= render_slot(@inner_block) %>
      </span>
      <span
        id={"#{@id}-content"}
        role="tooltip"
        class={[
          "pointer-events-none absolute bottom-full left-1/2 -translate-x-1/2 mb-2 z-50",
          "w-56 rounded-lg bg-gray-800 text-white text-xs p-2 text-center",
          "opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 transition-opacity"
        ]}
      >
        <%= @text %>
      </span>
    </span>
    """
  end
end
