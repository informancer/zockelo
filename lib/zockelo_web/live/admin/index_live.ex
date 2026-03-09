defmodule ZockeloWeb.Admin.IndexLive do
  use ZockeloWeb, :live_view

  alias Zockelo.{Tenants, SuperAdmins, SystemConfig}

  @impl true
  def mount(_params, _session, socket) do
    tenants = Tenants.list_tenants()
    super_admins = SuperAdmins.list_super_admins()
    config = SystemConfig.all()

    {:ok,
     socket
     |> assign(:tenants, tenants)
     |> assign(:super_admins, super_admins)
     |> assign(:config, config)
     |> assign(:page_title, "Super Admin Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-6 space-y-8">
      <h1 class="text-2xl font-bold">Super Admin Dashboard</h1>

      <section>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold">Leagues</h2>
          <.link navigate={~p"/admin/tenants/new"} class="btn btn-primary">New League</.link>
        </div>

        <%= if @tenants == [] do %>
          <div class="rounded-lg border-2 border-dashed border-gray-300 p-10 text-center">
            <p class="text-gray-500 mb-4">No leagues yet.</p>
            <.link navigate={~p"/admin/tenants/new"} class="btn btn-primary">Create your first league</.link>
          </div>
        <% else %>
          <div class="overflow-hidden rounded-lg border border-gray-200">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Name</th>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Slug</th>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Status</th>
                  <th class="px-4 py-3"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100 bg-white">
                <%= for tenant <- @tenants do %>
                  <tr>
                    <td class="px-4 py-3 font-medium"><%= tenant.name %></td>
                    <td class="px-4 py-3 text-gray-500"><%= tenant.slug %></td>
                    <td class="px-4 py-3">
                      <span class={"text-xs font-semibold px-2 py-1 rounded-full #{status_class(tenant.status)}"}>
                        <%= tenant.status %>
                      </span>
                    </td>
                    <td class="px-4 py-3 text-right">
                      <.link navigate={~p"/admin/tenants/#{tenant.id}"} class="text-sm text-blue-600 hover:underline">View</.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>

      <section>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold">Pending Requests</h2>
          <.link navigate={~p"/admin/tenants/requests"} class="text-sm text-blue-600 hover:underline">View all</.link>
        </div>
        <p class="text-sm text-gray-500">
          <%= Enum.count(@tenants, &(&1.status == "pending")) %> pending
        </p>
      </section>

      <section>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold">System Config</h2>
          <.link navigate={~p"/admin/config"} class="text-sm text-blue-600 hover:underline">Edit</.link>
        </div>
        <dl class="grid grid-cols-2 gap-4">
          <div>
            <dt class="text-sm text-gray-500">Tenant creation mode</dt>
            <dd class="font-medium"><%= @config["tenant_creation_mode"] %></dd>
          </div>
          <div>
            <dt class="text-sm text-gray-500">Audit log retention (days)</dt>
            <dd class="font-medium"><%= @config["audit_log_retention_days"] %></dd>
          </div>
        </dl>
      </section>

      <section>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold">Super Admins</h2>
          <.link navigate={~p"/admin/super-admins"} class="text-sm text-blue-600 hover:underline">Manage</.link>
        </div>
        <p class="text-sm text-gray-500"><%= length(@super_admins) %> super admin(s)</p>
      </section>
    </div>
    """
  end

  defp status_class("active"), do: "bg-green-100 text-green-800"
  defp status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_class("rejected"), do: "bg-red-100 text-red-800"
  defp status_class("deletion_pending"), do: "bg-orange-100 text-orange-800"
  defp status_class("deleted"), do: "bg-gray-100 text-gray-500"
  defp status_class(_), do: "bg-gray-100 text-gray-600"
end
