defmodule ZockeloWeb.Admin.SystemConfigLive do
  @moduledoc "Super admin panel for system configuration."
  use ZockeloWeb, :live_view

  alias Zockelo.SystemConfig

  @impl true
  def mount(_params, _session, socket) do
    config = SystemConfig.all()
    {:ok,
     socket
     |> assign(:form, to_form(config))
     |> assign(:page_title, "System Config")}
  end

  @impl true
  def handle_event("save", params, socket) do
    mode = Map.get(params, "tenant_creation_mode", SystemConfig.default("tenant_creation_mode"))
    days_raw = Map.get(params, "audit_log_retention_days", "730")

    with {days, ""} <- Integer.parse(days_raw),
         true <- days >= 90 do
      SystemConfig.put("tenant_creation_mode", mode)
      SystemConfig.put("audit_log_retention_days", days)

      {:noreply, put_flash(socket, :info, "Config saved.")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "audit_log_retention_days must be an integer ≥ 90.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto p-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">System Config</h1>
        <.link navigate={~p"/admin"} class="text-sm text-blue-600 hover:underline">← Back</.link>
      </div>

      <.form for={@form} phx-submit="save" class="space-y-6">
        <div>
          <label class="block text-sm font-medium mb-2">Tenant creation mode</label>
          <select name="tenant_creation_mode" class="select select-bordered w-full">
            <option value="direct" selected={@form[:tenant_creation_mode].value == "direct"}>
              Direct (super admin creates tenants immediately)
            </option>
            <option value="request_approval" selected={@form[:tenant_creation_mode].value == "request_approval"}>
              Request + Approval (users submit requests)
            </option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Audit log retention (days)</label>
          <.input field={@form[:audit_log_retention_days]} type="number" min="90" />
          <p class="text-xs text-gray-500 mt-1">Minimum 90 days. Default: 730.</p>
        </div>

        <.button type="submit">Save Config</.button>
      </.form>
    </div>
    """
  end
end
