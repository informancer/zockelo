defmodule ZockeloWeb.Tenant.PrivacySummaryLive do
  @moduledoc "Privacy summary screen shown once after first activation: /:tenant_slug/privacy-summary"
  use ZockeloWeb, :live_view

  alias Zockelo.Players

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user

    # Skip if already accepted
    if current_user.privacy_accepted_at do
      {:ok, redirect(socket, to: default_next(current_user, tenant))}
    else
      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:current_user, current_user)
       |> assign(:page_title, "Privacy Summary")}
    end
  end

  @impl true
  def handle_params(%{"next" => next}, _uri, socket) do
    {:noreply, assign(socket, :next, sanitize_next(next, socket.assigns.tenant))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :next, default_next(socket.assigns.current_user, socket.assigns.tenant))}
  end

  @impl true
  def handle_event("accept", _params, socket) do
    player_id = socket.assigns.current_user.player_id
    :ok = Players.accept_privacy(player_id)

    {:noreply, push_navigate(socket, to: socket.assigns.next)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
      <div class="max-w-lg w-full space-y-6">
        <div class="text-center">
          <h1 class="text-xl font-bold text-gray-800">Before you continue</h1>
          <p class="text-gray-500 text-sm mt-1">A quick summary of what <%= app_name(@tenant) %> stores about you.</p>
        </div>

        <div class="rounded-xl border bg-white p-6 space-y-4 text-sm text-gray-700">
          <div class="flex gap-3">
            <span class="text-blue-400 text-lg">👤</span>
            <div>
              <p class="font-medium">Display name and email address</p>
              <p class="text-gray-500">Used to identify you in the league and to send sign-in links.</p>
            </div>
          </div>
          <div class="flex gap-3">
            <span class="text-blue-400 text-lg">🎮</span>
            <div>
              <p class="font-medium">Game participation</p>
              <p class="text-gray-500">Your Elo rating and game history are kept to power the leaderboard.</p>
            </div>
          </div>
          <div class="flex gap-3">
            <span class="text-blue-400 text-lg">🔒</span>
            <div>
              <p class="font-medium">Encrypted at rest</p>
              <p class="text-gray-500">
                Your name and email are encrypted with a key unique to your account.
                Deleting your account permanently destroys the key — your personal data
                becomes unreadable (crypto-shredding).
              </p>
            </div>
          </div>
        </div>

        <div class="text-center space-y-2">
          <button phx-click="accept" class="btn btn-primary w-full">I understand — continue</button>
          <p class="text-xs text-gray-400">
            By continuing you acknowledge you have read this summary.
          </p>
        </div>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp default_next(%{role: "tenant_admin"}, tenant), do: "/#{tenant.slug}/admin"
  defp default_next(_user, tenant), do: "/#{tenant.slug}/"

  # Only accept relative paths that start with /
  defp sanitize_next("/" <> _ = path, _tenant), do: path
  defp sanitize_next(_, tenant), do: "/#{tenant.slug}/"

  defp app_name(%{config: config}) when is_map(config) do
    Map.get(config, "app_name") || "Zockelo"
  end
  defp app_name(_), do: "Zockelo"
end
