defmodule ZockeloWeb.Tenant.LoginLive do
  @moduledoc "Magic link login request: /:tenant_slug/login"
  use ZockeloWeb, :live_view

  alias Zockelo.{Auth, Players, Tenants, RateLimiter}

  @impl true
  def mount(%{"tenant_slug" => slug}, _session, socket) do
    tenant = Tenants.get_tenant_by_slug(slug)

    if is_nil(tenant) do
      {:ok, redirect(socket, to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:page_title, "Sign in — #{app_name(tenant)}")
       |> assign(:submitted, false)
       |> assign(:error, nil)
       |> assign(:peer_ip, RateLimiter.peer_ip(socket))}
    end
  end

  @impl true
  def handle_event("login", %{"email" => email}, socket) when byte_size(email) > 0 do
    ip = socket.assigns.peer_ip
    identifier = "#{email}:#{ip}"

    case RateLimiter.check(:magic_link, identifier) do
      {:error, :rate_limited} ->
        {:noreply, assign(socket, :submitted, true)}

      :ok ->
        tenant = socket.assigns.tenant

        # Look up player — silently do nothing if not found (no email enumeration)
        case Players.find_player_by_email(tenant.id, email) do
          {:ok, player_id} -> Auth.generate_magic_link(email, tenant.id, player_id)
          {:error, :not_found} -> :ok
        end

        # Always show "check your email" regardless of outcome
        {:noreply, assign(socket, :submitted, true)}
    end
  end

  def handle_event("login", _params, socket) do
    {:noreply, assign(socket, :error, "Please enter your email address.")}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, submitted: false, error: nil)}
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
          <div class="rounded-lg bg-green-50 border border-green-200 p-6 text-center space-y-2">
            <p class="font-semibold text-green-700">Check your email</p>
            <p class="text-sm text-green-600">
              We sent a sign-in link to your inbox. It expires in 15 minutes.
            </p>
            <p class="text-xs text-gray-400 mt-3">
              Didn't get it? Check your spam folder or
              <button phx-click="reset" class="underline text-blue-500">try again</button>.
            </p>
          </div>
        <% else %>
          <form phx-submit="login" class="space-y-4">
            <%= if @error do %>
              <div class="rounded bg-red-50 border border-red-200 px-3 py-2 text-sm text-red-600">
                <%= @error %>
              </div>
            <% end %>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Email address</label>
              <input type="email" name="email" required autofocus
                     class="input input-bordered w-full"
                     placeholder="you@example.com" />
            </div>
            <button type="submit" class="btn btn-primary w-full">Send magic link</button>
          </form>
        <% end %>

        <p class="text-center text-sm text-gray-400">
          Don't have an account? Ask your league admin for an invite.
        </p>
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
