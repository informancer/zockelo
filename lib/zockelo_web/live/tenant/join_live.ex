defmodule ZockeloWeb.Tenant.JoinLive do
  @moduledoc "Self-registration via invite link: /:tenant_slug/join?code={token}"
  use ZockeloWeb, :live_view

  alias Zockelo.{Auth, Players, Tenants, RateLimiter}

  @impl true
  def mount(%{"tenant_slug" => slug} = params, _session, socket) do
    tenant = Tenants.get_tenant_by_slug(slug)

    if is_nil(tenant) do
      {:ok, redirect(socket, to: ~p"/")}
    else
      code = params["code"]
      invite_valid = validate_invite(code, tenant.id)

      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:code, code)
       |> assign(:invite_valid, invite_valid)
       |> assign(:page_title, "Join #{app_name(tenant)}")
       |> assign(:submitted, false)
       |> assign(:error, nil)
       |> assign(:peer_ip, RateLimiter.peer_ip(socket))}
    end
  end

  @impl true
  def handle_event("register", %{"email" => email, "name" => name}, socket)
      when byte_size(email) > 0 and byte_size(name) > 0 do
    case RateLimiter.check(:join, socket.assigns.peer_ip) do
      {:error, :rate_limited} ->
        {:noreply, assign(socket, :error, "Too many attempts. Please wait and try again.")}

      :ok ->
        tenant = socket.assigns.tenant

        case Auth.validate_invite_link(socket.assigns.code, tenant.id) do
          {:ok, _tenant_id} ->
            case Players.invite_player(tenant.id, email, "invite_link") do
              {:ok, _player_id} ->
                {:noreply, assign(socket, :submitted, true)}

              {:error, reason} ->
                {:noreply, assign(socket, :error, "Registration failed: #{inspect(reason)}")}
            end

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:invite_valid, false)
             |> assign(:error, "This invite link is no longer valid.")}
        end
    end
  end

  def handle_event("register", _params, socket) do
    {:noreply, assign(socket, :error, "Please fill in all fields.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
      <div class="max-w-sm w-full space-y-6">
        <div class="text-center">
          <h1 class="text-2xl font-bold text-blue-600"><%= app_name(@tenant) %></h1>
          <p class="text-gray-500 mt-1">Join the league</p>
        </div>

        <%= cond do %>
          <% not @invite_valid -> %>
            <div class="rounded-lg bg-red-50 border border-red-200 p-6 text-center text-red-700 space-y-2">
              <p class="font-semibold">This invite link is no longer valid.</p>
              <p class="text-sm">Ask your league admin for a fresh link.</p>
            </div>

          <% @submitted -> %>
            <div class="rounded-lg bg-green-50 border border-green-200 p-6 text-center space-y-2">
              <p class="font-semibold text-green-700">Check your email</p>
              <p class="text-sm text-green-600">
                We sent a sign-in link to your inbox. Click it to activate your account.
              </p>
            </div>

          <% true -> %>
            <form phx-submit="register" class="space-y-4">
              <%= if @error do %>
                <div class="rounded bg-red-50 border border-red-200 px-3 py-2 text-sm text-red-600">
                  <%= @error %>
                </div>
              <% end %>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Your name</label>
                <input type="text" name="name" required autofocus
                       class="input input-bordered w-full"
                       placeholder="Alex" maxlength="50" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email address</label>
                <input type="email" name="email" required
                       class="input input-bordered w-full"
                       placeholder="you@example.com" />
              </div>
              <button type="submit" class="btn btn-primary w-full">Create account</button>
            </form>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp validate_invite(nil, _tenant_id), do: false
  defp validate_invite("", _tenant_id), do: false

  defp validate_invite(code, tenant_id) do
    case Auth.validate_invite_link(code, tenant_id) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp app_name(%{config: config}) when is_map(config) do
    Map.get(config, "app_name") || "Zockelo"
  end
  defp app_name(_), do: "Zockelo"
end
