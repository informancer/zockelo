defmodule ZockeloWeb.Tenant.ProfileSettingsLive do
  @moduledoc "Profile settings: /:tenant_slug/settings"
  use ZockeloWeb, :live_view

  alias Zockelo.{Players, Games}

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:current_user, current_user)
     |> assign(:page_title, "Settings")
     |> assign(:name_form, %{"name" => ""})
     |> assign(:email_form, %{"email" => ""})
     |> assign(:confirm_delete, false)
     |> assign(:flash_msg, nil)
     |> assign(:section, "profile")}
  end

  # ---------------------------------------------------------------------------
  # Name change
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("update_name", %{"name" => name}, socket) when byte_size(name) > 0 do
    player_id = socket.assigns.current_user.player_id
    tenant_id = socket.assigns.tenant.id

    case Players.update_player_name(player_id, tenant_id, name) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Name updated.")
         |> assign(:name_form, %{"name" => ""})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("update_name", _params, socket) do
    {:noreply, put_flash(socket, :error, "Name cannot be blank.")}
  end

  # ---------------------------------------------------------------------------
  # Email change
  # ---------------------------------------------------------------------------

  def handle_event("initiate_email_change", %{"email" => email}, socket) when byte_size(email) > 0 do
    player_id = socket.assigns.current_user.player_id
    tenant_id = socket.assigns.tenant.id

    case Players.initiate_email_change(player_id, tenant_id, email) do
      {:ok, _token} ->
        {:noreply, put_flash(socket, :info, "Verification link sent to #{email}. Click it to confirm the change.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("initiate_email_change", _params, socket) do
    {:noreply, put_flash(socket, :error, "Email cannot be blank.")}
  end

  # ---------------------------------------------------------------------------
  # GDPR data export
  # ---------------------------------------------------------------------------

  def handle_event("export_data", _params, socket) do
    player_id = socket.assigns.current_user.player_id
    tenant_id = socket.assigns.tenant.id

    json = build_export(player_id, tenant_id)

    {:noreply,
     socket
     |> push_event("download_json", %{filename: "my_data.json", content: json})}
  end

  # ---------------------------------------------------------------------------
  # Account deletion
  # ---------------------------------------------------------------------------

  def handle_event("confirm_delete_account", _params, socket) do
    {:noreply, assign(socket, :confirm_delete, true)}
  end

  def handle_event("cancel_delete_account", _params, socket) do
    {:noreply, assign(socket, :confirm_delete, false)}
  end

  def handle_event("delete_account", _params, socket) do
    player_id = socket.assigns.current_user.player_id
    tenant_id = socket.assigns.tenant.id

    :ok = Players.delete_player(player_id, tenant_id, player_id)

    {:noreply,
     socket
     |> put_flash(:info, "Your account has been deleted.")
     |> push_navigate(to: ~p"/#{socket.assigns.tenant.slug}/login")}
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-16 sm:pb-0">
      <ZockeloWeb.NavComponent.tenant_nav tenant={@tenant} current_user={@current_user} active="settings" />

      <div class="max-w-xl mx-auto p-4 sm:p-6 space-y-8">
        <h1 class="text-2xl font-bold">Settings</h1>

        <!-- Name -->
        <section class="space-y-3">
          <h2 class="font-semibold">Display Name</h2>
          <form phx-submit="update_name" class="flex gap-3">
            <input type="text" name="name" placeholder="Your display name"
                   class="input input-bordered flex-1" required />
            <button type="submit" class="btn btn-primary">Save</button>
          </form>
        </section>

        <!-- Email -->
        <section class="space-y-3">
          <h2 class="font-semibold">Change Email</h2>
          <p class="text-sm text-gray-500">A verification link will be sent to the new address.</p>
          <form phx-submit="initiate_email_change" class="flex gap-3">
            <input type="email" name="email" placeholder="new@example.com"
                   class="input input-bordered flex-1" required />
            <button type="submit" class="btn btn-secondary">Send Link</button>
          </form>
        </section>

        <!-- Data export -->
        <section class="space-y-3">
          <h2 class="font-semibold">Export My Data</h2>
          <p class="text-sm text-gray-500">Download a JSON file with your profile and game history.</p>
          <button phx-click="export_data" class="btn btn-outline">Download my data</button>
        </section>

        <!-- Danger zone -->
        <section class="rounded-xl border border-red-200 bg-red-50 p-4 space-y-3">
          <h2 class="font-semibold text-red-700">Delete Account</h2>
          <p class="text-sm text-red-600">
            This permanently deletes your account and crypto-shreds all personal data. This cannot be undone.
          </p>
          <%= if @confirm_delete do %>
            <div class="flex gap-3">
              <button phx-click="delete_account" class="btn btn-error btn-sm">Yes, delete my account</button>
              <button phx-click="cancel_delete_account" class="btn btn-sm">Cancel</button>
            </div>
          <% else %>
            <button phx-click="confirm_delete_account" class="btn btn-error btn-outline btn-sm">
              Delete my account
            </button>
          <% end %>
        </section>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_export(player_id, tenant_id) do
    games =
      import Ecto.Query

      alias Zockelo.Projections.GameRead
      alias Zockelo.Repo

      Repo.all(
        from g in GameRead,
          where:
            g.tenant_id == ^tenant_id and
              (fragment("?::uuid = ANY(?)", ^player_id, g.team1_players) or
                 fragment("?::uuid = ANY(?)", ^player_id, g.team2_players)),
          order_by: [desc: g.logged_at]
      )
      |> Enum.map(fn g ->
        %{
          id: g.id,
          status: g.status,
          logged_at: g.logged_at
        }
      end)

    profile = Players.get_player(player_id)

    Jason.encode!(%{
      exported_at: DateTime.utc_now(),
      player_id: player_id,
      status: profile && profile.status,
      games: games
    }, pretty: true)
  end
end
