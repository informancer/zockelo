defmodule ZockeloWeb.Admin.TenantDetailLive do
  @moduledoc "Super admin detail view for a tenant."
  use ZockeloWeb, :live_view

  alias Zockelo.Tenants

  @impl true
  def mount(%{"tenant_id" => tenant_id}, _session, socket) do
    case Tenants.get_tenant(tenant_id) do
      nil ->
        {:ok, socket |> put_flash(:error, "Tenant not found.") |> push_navigate(to: ~p"/admin")}

      tenant ->
        players = Tenants.list_players(tenant_id)
        stats = Tenants.tenant_stats(tenant_id)

        {:ok,
         socket
         |> assign(:tenant, tenant)
         |> assign(:players, players)
         |> assign(:stats, stats)
         |> assign(:page_title, tenant.name)}
    end
  end

  @impl true
  def handle_event("request_deletion", _params, socket) do
    player_id = socket.assigns.current_session.player_id
    tenant = socket.assigns.tenant

    case Tenants.request_deletion(tenant.id, player_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Deletion initiated. Grace period: 48 hours.")
         |> assign(:tenant, Tenants.get_tenant(tenant.id))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("cancel_deletion", _params, socket) do
    player_id = socket.assigns.current_session.player_id
    tenant = socket.assigns.tenant

    case Tenants.cancel_deletion(tenant.id, player_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Deletion cancelled.")
         |> assign(:tenant, Tenants.get_tenant(tenant.id))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 space-y-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold"><%= @tenant.name %></h1>
          <p class="text-gray-500">/<%= @tenant.slug %></p>
        </div>
        <div class="flex items-center gap-3">
          <span class={"text-xs font-semibold px-2 py-1 rounded-full #{status_class(@tenant.status)}"}>
            <%= @tenant.status %>
          </span>
          <.link navigate={~p"/admin"} class="text-sm text-blue-600 hover:underline">← Back</.link>
        </div>
      </div>

      <section>
        <h2 class="text-lg font-semibold mb-3">Stats</h2>
        <dl class="grid grid-cols-2 gap-4">
          <div>
            <dt class="text-sm text-gray-500">Players</dt>
            <dd class="text-2xl font-bold"><%= @stats.player_count %></dd>
          </div>
          <div>
            <dt class="text-sm text-gray-500">Games logged</dt>
            <dd class="text-2xl font-bold"><%= @stats.game_count %></dd>
          </div>
        </dl>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Config</h2>
        <pre class="bg-gray-50 rounded p-4 text-sm overflow-auto"><%= Jason.encode!(@tenant.config, pretty: true) %></pre>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Players</h2>
        <%= if @players == [] do %>
          <p class="text-gray-500">No players yet.</p>
        <% else %>
          <div class="overflow-hidden rounded-lg border border-gray-200">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Player ID</th>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Role</th>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Status</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100 bg-white">
                <%= for player <- @players do %>
                  <tr>
                    <td class="px-4 py-3 font-mono text-sm"><%= player.player_id %></td>
                    <td class="px-4 py-3"><%= player.role %></td>
                    <td class="px-4 py-3"><%= player.status %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3 text-red-700">Danger Zone</h2>
        <%= if @tenant.status == "active" do %>
          <button phx-click="request_deletion"
                  data-confirm={"Delete league #{@tenant.name}? This cannot be undone after the grace period."}
                  class="btn btn-error">
            Initiate Deletion
          </button>
        <% end %>
        <%= if @tenant.status == "deletion_pending" do %>
          <p class="text-orange-600 mb-2">Deletion is pending (48h grace period).</p>
          <button phx-click="cancel_deletion" class="btn btn-warning">
            Cancel Deletion
          </button>
        <% end %>
      </section>
    </div>
    """
  end

  defp status_class("active"), do: "bg-green-100 text-green-800"
  defp status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_class("deletion_pending"), do: "bg-orange-100 text-orange-800"
  defp status_class("deleted"), do: "bg-gray-100 text-gray-500"
  defp status_class(_), do: "bg-gray-100 text-gray-600"
end
