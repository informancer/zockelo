defmodule ZockeloWeb.Tenant.ActivateLive do
  @moduledoc "First-login activation: /:tenant_slug/activate — player sets their display name."
  use ZockeloWeb, :live_view

  alias Zockelo.Players

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user

    # Redirect if already activated
    if current_user.status != "invited" do
      {:ok, redirect(socket, to: ~p"/#{tenant.slug}/")}
    else
      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:current_user, current_user)
       |> assign(:page_title, "Welcome to #{app_name(tenant)}")
       |> assign(:error, nil)}
    end
  end

  @impl true
  def handle_event("activate", %{"name" => name}, socket) when byte_size(name) > 0 do
    player_id = socket.assigns.current_user.player_id
    tenant_id = socket.assigns.tenant.id
    tenant = socket.assigns.tenant

    case Players.activate_player(player_id, tenant_id, name) do
      :ok ->
        next =
          if socket.assigns.current_user.role == "tenant_admin",
            do: "/#{tenant.slug}/admin",
            else: "/#{tenant.slug}/"

        {:noreply,
         push_navigate(socket,
           to: ~p"/#{tenant.slug}/privacy-summary?next=#{URI.encode(next)}"
         )}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Could not activate account: #{inspect(reason)}")}
    end
  end

  def handle_event("activate", _params, socket) do
    {:noreply, assign(socket, :error, "Please enter a display name.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
      <div class="max-w-sm w-full space-y-6">
        <div class="text-center">
          <h1 class="text-2xl font-bold text-blue-600">Welcome!</h1>
          <p class="text-gray-500 mt-1">Choose a display name to get started.</p>
        </div>

        <form phx-submit="activate" class="space-y-4">
          <%= if @error do %>
            <div class="rounded bg-red-50 border border-red-200 px-3 py-2 text-sm text-red-600">
              <%= @error %>
            </div>
          <% end %>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Display name</label>
            <input type="text" name="name" required autofocus
                   class="input input-bordered w-full"
                   placeholder="e.g. Alex" maxlength="50" />
            <p class="text-xs text-gray-400 mt-1">This is how other players will see you.</p>
          </div>
          <button type="submit" class="btn btn-primary w-full">Continue</button>
        </form>
      </div>
    </div>
    """
  end

  defp app_name(%{config: config}) when is_map(config) do
    Map.get(config, "app_name") || "Zockelo"
  end
  defp app_name(_), do: "Zockelo"
end
