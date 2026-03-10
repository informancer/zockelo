defmodule ZockeloWeb.Admin.SystemConfigLive do
  @moduledoc "Super admin panel for system configuration."
  use ZockeloWeb, :live_view

  alias Zockelo.SystemConfig
  alias Zockelo.Notifications
  alias Zockelo.Workers.MaintenanceBroadcastWorker

  @impl true
  def mount(_params, _session, socket) do
    config = SystemConfig.all()
    {:ok,
     socket
     |> assign(:form, to_form(config))
     |> assign(:broadcast_sent, false)
     |> assign(:page_title, "System Config")}
  end

  @impl true
  def handle_event("save", params, socket) do
    mode = Map.get(params, "tenant_creation_mode", SystemConfig.default("tenant_creation_mode"))
    days_raw = Map.get(params, "audit_log_retention_days", "730")
    maintenance_message = params["maintenance_message"] || ""
    maintenance_scheduled_at = params["maintenance_scheduled_at"] || ""

    with {days, ""} <- Integer.parse(days_raw),
         true <- days >= 90 do
      SystemConfig.put("tenant_creation_mode", mode)
      SystemConfig.put("audit_log_retention_days", days)
      SystemConfig.put("maintenance_message", maintenance_message)
      SystemConfig.put("maintenance_scheduled_at", maintenance_scheduled_at)

      {:noreply,
       socket
       |> assign(:form, to_form(SystemConfig.all()))
       |> put_flash(:info, "Config saved.")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "audit_log_retention_days must be an integer ≥ 90.")}
    end
  end

  def handle_event("send_maintenance_email", _params, socket) do
    message = SystemConfig.get("maintenance_message")

    if message && message != "" do
      {:ok, _job} = Oban.insert(MaintenanceBroadcastWorker.new(%{"message" => message}))
      {:noreply,
       socket
       |> assign(:broadcast_sent, true)
       |> put_flash(:info, "Maintenance email broadcast queued.")}
    else
      {:noreply, put_flash(socket, :error, "Set a maintenance message before sending.")}
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

        <div class="border-t pt-4">
          <h2 class="font-semibold mb-3">Maintenance Mode</h2>
          <div class="space-y-3">
            <div>
              <label class="block text-sm font-medium mb-1">Maintenance message</label>
              <textarea
                name="maintenance_message"
                rows="3"
                placeholder="Leave blank to hide the banner."
                class="w-full rounded border border-gray-300 p-2 text-sm"
              ><%= @form[:maintenance_message].value %></textarea>
              <p class="text-xs text-gray-500 mt-1">
                Shown as a banner on all pages. Clear to end maintenance mode.
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium mb-1">Scheduled at (optional)</label>
              <.input
                field={@form[:maintenance_scheduled_at]}
                type="datetime-local"
              />
              <p class="text-xs text-gray-500 mt-1">
                Displayed alongside the message. Does not enforce or automate anything.
              </p>
            </div>
          </div>
        </div>

        <.button type="submit">Save Config</.button>
      </.form>

      <div class="border-t pt-4 mt-6">
        <h2 class="font-semibold mb-2">Maintenance Email Broadcast</h2>
        <p class="text-sm text-gray-600 mb-3">
          Sends the current maintenance message to all active players who have
          <em>maintenance announcements</em> notifications enabled.
        </p>
        <.button
          type="button"
          phx-click="send_maintenance_email"
          disabled={@broadcast_sent}
          class="bg-yellow-600 hover:bg-yellow-700"
        >
          <%= if @broadcast_sent, do: "Broadcast Queued ✓", else: "Send Maintenance Email" %>
        </.button>
      </div>
    </div>
    """
  end
end
