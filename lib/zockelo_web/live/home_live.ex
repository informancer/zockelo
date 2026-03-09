defmodule ZockeloWeb.HomeLive do
  @moduledoc "Root landing page: /"
  use ZockeloWeb, :live_view

  on_mount {ZockeloWeb.Live.AuthHooks, :load_session}

  import Ecto.Query

  alias Zockelo.{Tenants, SuperAdmins}
  alias Zockelo.Repo
  alias Zockelo.Projections.PlayerProfile
  alias Zockelo.SuperAdmins.SuperAdmin

  @impl true
  def mount(_params, _session, socket) do
    super_admin_exists = Repo.exists?(SuperAdmin)
    tenants = Tenants.list_tenants()
    tenants_exist = tenants != []
    session = socket.assigns[:current_session]

    socket = assign(socket, :page_title, "Zockelo")

    cond do
      # (a) No super admin → getting started
      not super_admin_exists ->
        {:ok, assign(socket, :view, :getting_started)}

      # (b/c) Super admin exists, no tenants
      not tenants_exist ->
        if authed_super_admin?(session) do
          {:ok, redirect(socket, to: ~p"/admin")}
        else
          {:ok, assign(socket, :view, :no_leagues)}
        end

      # (d/e/f) Tenants exist
      true ->
        if session do
          player_id = session.player_id

          if SuperAdmins.super_admin?(player_id) do
            # (e) Super admin → /admin
            {:ok, redirect(socket, to: ~p"/admin")}
          else
            # (d) Regular player → their first tenant
            profile = Repo.one(from p in PlayerProfile, where: p.player_id == ^player_id, limit: 1)

            if profile do
              tenant = Tenants.get_tenant(profile.tenant_id)
              {:ok, redirect(socket, to: ~p"/#{tenant.slug}/")}
            else
              # Authenticated but not in any tenant
              {:ok, assign(socket, :view, :enter_slug)}
            end
          end
        else
          # (f) Unauthenticated → enter league URL
          {:ok, assign(socket, :view, :enter_slug)}
        end
    end
  end

  @impl true
  def handle_event("enter_slug", %{"slug" => slug}, socket) when byte_size(slug) > 0 do
    {:noreply, push_navigate(socket, to: ~p"/#{slug}/login")}
  end

  def handle_event("enter_slug", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <%= case assigns[:view] do %>
      <% :getting_started -> %>
        <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
          <div class="max-w-lg w-full space-y-6 text-center">
            <h1 class="text-3xl font-bold text-blue-600">Welcome to Zockelo</h1>
            <p class="text-gray-600">
              No administrator account has been set up yet.
              Run the following command to create the first super admin:
            </p>
            <pre class="bg-gray-800 text-green-400 rounded-lg p-4 text-left text-sm overflow-x-auto">
./bin/zockelo eval 'Zockelo.ReleaseTasks.create_super_admin("admin@example.com")'
            </pre>
            <p class="text-sm text-gray-400">
              In development, use: <code class="bg-gray-100 px-1 rounded">mix zockelo.create_super_admin --email admin@example.com</code>
            </p>
          </div>
        </div>

      <% :no_leagues -> %>
        <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
          <div class="max-w-md w-full space-y-4 text-center">
            <h1 class="text-2xl font-bold text-gray-800">No leagues available yet</h1>
            <p class="text-gray-500">
              The administrator hasn't created any leagues. Check back soon.
            </p>
          </div>
        </div>

      <% :enter_slug -> %>
        <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
          <div class="max-w-md w-full space-y-6">
            <div class="text-center">
              <h1 class="text-3xl font-bold text-blue-600">Zockelo</h1>
              <p class="text-gray-500 mt-1">Foosball Elo rating tracker</p>
            </div>
            <form phx-submit="enter_slug" class="space-y-3">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Enter your league URL
                </label>
                <div class="flex gap-2">
                  <span class="inline-flex items-center px-3 rounded-l-md border border-r-0 border-gray-300 bg-gray-50 text-gray-500 text-sm">
                    zockelo.app/
                  </span>
                  <input type="text" name="slug" placeholder="my-league"
                         class="input input-bordered flex-1 rounded-l-none"
                         autocomplete="off" required />
                </div>
              </div>
              <button type="submit" class="btn btn-primary w-full">Go to my league</button>
            </form>
          </div>
        </div>

      <% _ -> %>
        <%!-- Redirecting — nothing to render --%>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp authed_super_admin?(nil), do: false
  defp authed_super_admin?(session), do: SuperAdmins.super_admin?(session.player_id)
end
