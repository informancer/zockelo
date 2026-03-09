defmodule ZockeloWeb.Tenant.LoginLive do
  @moduledoc "Magic link login: /:tenant_slug/login — full implementation in section 13."
  use ZockeloWeb, :live_view

  alias Zockelo.Tenants

  @impl true
  def mount(%{"tenant_slug" => slug}, _session, socket) do
    tenant = Tenants.get_tenant_by_slug(slug)

    if is_nil(tenant) do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:page_title, "Login — #{app_name(tenant)}")
       |> assign(:submitted, false)}
    end
  end

  @impl true
  def handle_event("request_link", %{"email" => _email}, socket) do
    # Full implementation in section 13 (magic link generation + email dispatch)
    {:noreply, assign(socket, :submitted, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
      <div class="max-w-sm w-full space-y-6">
        <div class="text-center">
          <h1 class="text-2xl font-bold text-blue-600"><%= app_name(@tenant) %></h1>
          <p class="text-gray-500 mt-1">Sign in with a magic link</p>
        </div>

        <%= if @submitted do %>
          <div class="rounded-lg bg-green-50 border border-green-200 p-4 text-center text-sm text-green-700">
            Check your email for a login link.
          </div>
        <% else %>
          <form phx-submit="request_link" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Email address</label>
              <input type="email" name="email" required autofocus
                     class="input input-bordered w-full"
                     placeholder="you@example.com" />
            </div>
            <button type="submit" class="btn btn-primary w-full">Send magic link</button>
          </form>
        <% end %>
      </div>
    </div>
    """
  end

  defp app_name(%{config: config}) when is_map(config) do
    case Map.get(config, "app_name") do
      nil -> "Zockelo"
      "" -> "Zockelo"
      name -> name
    end
  end
  defp app_name(_), do: "Zockelo"
end
