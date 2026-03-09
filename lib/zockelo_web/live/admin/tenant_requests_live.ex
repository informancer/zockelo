defmodule ZockeloWeb.Admin.TenantRequestsLive do
  @moduledoc "Super admin queue for pending tenant requests."
  use ZockeloWeb, :live_view

  alias Zockelo.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:pending, Tenants.list_tenants_by_status("pending"))
     |> assign(:page_title, "Tenant Requests")}
  end

  @impl true
  def handle_event("approve", %{"id" => tenant_id}, socket) do
    player_id = socket.assigns.current_session.player_id

    case Tenants.approve_tenant(tenant_id, player_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Tenant approved.")
         |> assign(:pending, Tenants.list_tenants_by_status("pending"))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("reject", %{"id" => tenant_id}, socket) do
    player_id = socket.assigns.current_session.player_id

    case Tenants.reject_tenant(tenant_id, player_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Tenant rejected.")
         |> assign(:pending, Tenants.list_tenants_by_status("pending"))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Pending Tenant Requests</h1>
        <.link navigate={~p"/admin"} class="text-sm text-blue-600 hover:underline">← Back</.link>
      </div>

      <%= if @pending == [] do %>
        <p class="text-gray-500">No pending requests.</p>
      <% else %>
        <div class="space-y-4">
          <%= for tenant <- @pending do %>
            <div class="rounded-lg border border-gray-200 p-4 flex items-center justify-between">
              <div>
                <p class="font-medium"><%= tenant.name %></p>
                <p class="text-sm text-gray-500">/<%= tenant.slug %></p>
              </div>
              <div class="flex gap-2">
                <button phx-click="approve" phx-value-id={tenant.id}
                        class="btn btn-sm btn-success">Approve</button>
                <button phx-click="reject" phx-value-id={tenant.id}
                        class="btn btn-sm btn-error">Reject</button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
