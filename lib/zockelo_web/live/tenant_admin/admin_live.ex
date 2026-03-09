defmodule ZockeloWeb.TenantAdmin.AdminLive do
  @moduledoc """
  Tenant admin panel — tabbed layout: players, games, config, GDPR.

  Route: /:tenant_slug/admin
  """
  use ZockeloWeb, :live_view

  alias Zockelo.{Players, Auth, Games}
  alias Zockelo.Auth.InviteLink
  alias Zockelo.Crypto.GdprKeyDeletion
  alias Zockelo.Repo

  import Ecto.Query

  @tabs ~w(players config invite_links gdpr disputed_games deletion)

  @impl true
  def mount(%{"tenant_slug" => _slug}, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:tab, "players")
     |> assign(:tenant, tenant)
     |> assign(:current_user, current_user)
     |> assign(:page_title, "#{tenant.name} — Admin")
     |> load_tab("players")}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) when tab in @tabs do
    {:noreply, socket |> assign(:tab, tab) |> load_tab(tab)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Player tab events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("invite_player", %{"email" => email}, socket) do
    tenant = socket.assigns.tenant
    invited_by = socket.assigns.current_user.player_id

    case Players.invite_player(tenant.id, email, invited_by) do
      {:ok, _player_id} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}.")
         |> load_tab("players")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  def handle_event("resend_invite", %{"player_id" => player_id}, socket) do
    tenant = socket.assigns.tenant

    case Players.resend_magic_link(player_id, tenant.id) do
      :ok -> {:noreply, put_flash(socket, :info, "Magic link resent.")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("confirm_delete_player", %{"player_id" => player_id}, socket) do
    {:noreply, assign(socket, :confirm_delete_player_id, player_id)}
  end

  def handle_event("cancel_delete_player", _params, socket) do
    {:noreply, assign(socket, :confirm_delete_player_id, nil)}
  end

  def handle_event("delete_player", %{"player_id" => player_id}, socket) do
    tenant = socket.assigns.tenant
    deleted_by = socket.assigns.current_user.player_id

    case Players.delete_player(player_id, tenant.id, deleted_by) do
      :ok ->
        {:noreply,
         socket
         |> assign(:confirm_delete_player_id, nil)
         |> put_flash(:info, "Player deleted.")
         |> load_tab("players")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  # ---------------------------------------------------------------------------
  # Role management events
  # ---------------------------------------------------------------------------

  def handle_event("grant_admin", %{"player_id" => player_id}, socket) do
    tenant = socket.assigns.tenant
    :ok = Players.grant_admin(player_id, tenant.id)
    {:noreply, socket |> put_flash(:info, "Admin role granted.") |> load_tab("players")}
  end

  def handle_event("revoke_admin", %{"player_id" => player_id}, socket) do
    tenant = socket.assigns.tenant
    :ok = Players.revoke_admin(player_id, tenant.id)
    {:noreply, socket |> put_flash(:info, "Admin role revoked.") |> load_tab("players")}
  end

  # ---------------------------------------------------------------------------
  # Config tab events
  # ---------------------------------------------------------------------------

  def handle_event("save_config", params, socket) do
    tenant = socket.assigns.tenant
    updated_by = socket.assigns.current_user.player_id

    # Extract allowed config fields
    config_keys = ~w(rounds_to_win points_per_round confirmation_mode
                     auto_confirm_after_hours retention_period_days
                     notify_admin_on_invite_expiry default_locale
                     deletion_grace_period_hours app_name custom_domain)

    changes =
      params
      |> Map.take(config_keys)
      |> Map.reject(fn {_, v} -> v == "" end)

    # Handle custom_domain separately (updates TenantRead directly)
    {custom_domain_change, config_changes} = Map.pop(changes, "custom_domain")

    if custom_domain_change do
      Repo.update_all(
        from(t in Zockelo.Projections.TenantRead, where: t.id == ^tenant.id),
        set: [custom_domain: custom_domain_change]
      )
    end

    if map_size(config_changes) > 0 do
      Players.update_tenant_config(tenant.id, config_changes, updated_by)
    end

    {:noreply, put_flash(socket, :info, "Config saved.")}
  end

  # ---------------------------------------------------------------------------
  # Invite links tab events
  # ---------------------------------------------------------------------------

  def handle_event("generate_invite_link", _params, socket) do
    tenant = socket.assigns.tenant
    created_by = socket.assigns.current_user.player_id

    case Auth.generate_invite_link(tenant.id, created_by, []) do
      {:ok, _link} ->
        {:noreply, socket |> put_flash(:info, "Invite link generated.") |> load_tab("invite_links")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("rotate_invite_link", %{"link_id" => link_id}, socket) do
    tenant = socket.assigns.tenant
    created_by = socket.assigns.current_user.player_id

    # Fetch the current token for this link_id
    link = Repo.get(InviteLink, link_id)

    case Auth.rotate_invite_link(tenant.id, link.token, created_by) do
      {:ok, _new_link} ->
        {:noreply, socket |> put_flash(:info, "Invite link rotated.") |> load_tab("invite_links")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("set_invite_expiry", %{"link_id" => link_id, "expires_at" => expires_str}, socket) do
    import Ecto.Query

    expires_at =
      case DateTime.from_iso8601(expires_str <> ":00Z") do
        {:ok, dt, _} -> dt
        _ -> nil
      end

    Repo.update_all(
      from(l in InviteLink, where: l.id == ^link_id),
      set: [expires_at: expires_at]
    )

    {:noreply, socket |> put_flash(:info, "Expiry updated.") |> load_tab("invite_links")}
  end

  # ---------------------------------------------------------------------------
  # Disputed games tab events
  # ---------------------------------------------------------------------------

  def handle_event("reinstate_game", %{"game_id" => game_id}, socket) do
    admin_id = socket.assigns.current_user.player_id

    case Games.reinstate_game(game_id, admin_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Game reinstated.")
         |> load_tab("disputed_games")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("void_game", %{"game_id" => game_id}, socket) do
    admin_id = socket.assigns.current_user.player_id

    case Games.void_game(game_id, admin_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Game voided.")
         |> load_tab("disputed_games")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  # ---------------------------------------------------------------------------
  # Tenant deletion tab events
  # ---------------------------------------------------------------------------

  def handle_event("request_deletion", _params, socket) do
    tenant = socket.assigns.tenant
    requested_by = socket.assigns.current_user.player_id

    case Zockelo.Tenants.request_deletion(tenant.id, requested_by) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Deletion initiated. Grace period in effect.")
         |> assign(:tenant, Zockelo.Tenants.get_tenant(tenant.id))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("cancel_deletion", _params, socket) do
    tenant = socket.assigns.tenant
    cancelled_by = socket.assigns.current_user.player_id

    case Zockelo.Tenants.cancel_deletion(tenant.id, cancelled_by) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Deletion cancelled.")
         |> assign(:tenant, Zockelo.Tenants.get_tenant(tenant.id))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold"><%= @tenant.name %> — Admin</h1>
        <.link navigate={"/" <> @tenant.slug} class="text-sm text-blue-600 hover:underline">
          ← Back to league
        </.link>
      </div>

      <div class="border-b border-gray-200 mb-6">
        <nav class="-mb-px flex gap-6">
          <.tab_link tab="players" current={@tab} slug={@tenant.slug}>Players</.tab_link>
          <.tab_link tab="config" current={@tab} slug={@tenant.slug}>Config</.tab_link>
          <.tab_link tab="invite_links" current={@tab} slug={@tenant.slug}>Invite Links</.tab_link>
          <.tab_link tab="gdpr" current={@tab} slug={@tenant.slug}>GDPR Audit</.tab_link>
          <.tab_link tab="disputed_games" current={@tab} slug={@tenant.slug}>Disputes</.tab_link>
          <.tab_link tab="deletion" current={@tab} slug={@tenant.slug}>Danger Zone</.tab_link>
        </nav>
      </div>

      <%= case @tab do %>
        <% "players" -> %><%= render_players(assigns) %>
        <% "config" -> %><%= render_config(assigns) %>
        <% "invite_links" -> %><%= render_invite_links(assigns) %>
        <% "gdpr" -> %><%= render_gdpr(assigns) %>
        <% "disputed_games" -> %><%= render_disputed_games(assigns) %>
        <% "deletion" -> %><%= render_deletion(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_players(assigns) do
    ~H"""
    <div class="space-y-6">
      <section>
        <h2 class="text-lg font-semibold mb-3">Invite a Player</h2>
        <form phx-submit="invite_player" class="flex gap-3">
          <input type="email" name="email" placeholder="player@example.com" required
                 class="input input-bordered flex-1" />
          <button type="submit" class="btn btn-primary">Send Invite</button>
        </form>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Active Players (<%= length(@active_players) %>)</h2>
        <%= if @active_players == [] do %>
          <p class="text-gray-500">No active players yet.</p>
        <% else %>
          <div class="overflow-hidden rounded-lg border border-gray-200">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Player ID</th>
                  <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Role</th>
                  <th class="px-4 py-3"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100 bg-white">
                <%= for player <- @active_players do %>
                  <tr>
                    <td class="px-4 py-3 font-mono text-sm"><%= player.player_id %></td>
                    <td class="px-4 py-3"><%= player.role %></td>
                    <td class="px-4 py-3 text-right flex gap-2 justify-end">
                      <%= if player.role == "player" do %>
                        <button phx-click="grant_admin" phx-value-player_id={player.player_id}
                                class="text-xs text-blue-600 hover:underline">Make admin</button>
                      <% else %>
                        <button phx-click="revoke_admin" phx-value-player_id={player.player_id}
                                class="text-xs text-gray-500 hover:underline">Revoke admin</button>
                      <% end %>
                      <button phx-click="confirm_delete_player" phx-value-player_id={player.player_id}
                              class="text-xs text-red-600 hover:underline">Delete</button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Pending Invitations (<%= length(@invited_players) %>)</h2>
        <%= if @invited_players == [] do %>
          <p class="text-gray-500">No pending invitations.</p>
        <% else %>
          <div class="space-y-2">
            <%= for player <- @invited_players do %>
              <div class="flex items-center justify-between rounded-lg border p-3">
                <span class="font-mono text-sm text-gray-600"><%= player.player_id %></span>
                <div class="flex gap-2">
                  <button phx-click="resend_invite" phx-value-player_id={player.player_id}
                          class="text-xs text-blue-600 hover:underline">Resend</button>
                  <button phx-click="confirm_delete_player" phx-value-player_id={player.player_id}
                          class="text-xs text-red-600 hover:underline">Delete</button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>

      <%= if @confirm_delete_player_id do %>
        <div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg p-6 max-w-sm w-full shadow-xl">
            <h3 class="text-lg font-semibold mb-2">Delete Player?</h3>
            <p class="text-sm text-gray-600 mb-4">
              This permanently deletes the player and crypto-shreds their PII. This cannot be undone.
            </p>
            <div class="flex gap-3">
              <button phx-click="delete_player" phx-value-player_id={@confirm_delete_player_id}
                      class="btn btn-error">Delete</button>
              <button phx-click="cancel_delete_player" class="btn">Cancel</button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_config(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold mb-4">League Configuration</h2>

      <form phx-submit="save_config" class="space-y-5 max-w-lg">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-1">Rounds to win</label>
            <input type="number" name="rounds_to_win" min="1" max="9"
                   value={get_in(@tenant.config, ["rounds_to_win"]) || 2}
                   class="input input-bordered w-full" />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">Points per round</label>
            <input type="number" name="points_per_round" min="1" max="99"
                   value={get_in(@tenant.config, ["points_per_round"]) || 7}
                   class="input input-bordered w-full" />
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Confirmation mode</label>
          <select name="confirmation_mode" class="select select-bordered w-full">
            <option value="trust" selected={get_in(@tenant.config, ["confirmation_mode"]) == "trust"}>
              Trust (games count immediately)
            </option>
            <option value="confirmation" selected={get_in(@tenant.config, ["confirmation_mode"]) == "confirmation"}>
              Confirmation required
            </option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Auto-confirm after (hours)</label>
          <input type="number" name="auto_confirm_after_hours" min="1"
                 value={get_in(@tenant.config, ["auto_confirm_after_hours"]) || 24}
                 class="input input-bordered w-full" />
          <p class="text-xs text-gray-500 mt-1">Only applies in confirmation mode.</p>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Default locale</label>
          <input type="text" name="default_locale" placeholder="en"
                 value={get_in(@tenant.config, ["default_locale"]) || "en"}
                 class="input input-bordered w-full" />
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Custom domain</label>
          <input type="text" name="custom_domain" placeholder="foosball.company.com"
                 value={@tenant.custom_domain}
                 class="input input-bordered w-full" />
          <p class="text-xs text-gray-500 mt-1">
            Point your domain's DNS A record to this server's IP, then add a Caddy reverse proxy entry
            for <code>foosball.company.com</code>. Contact your operator for instructions.
          </p>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">App name (branding)</label>
          <input type="text" name="app_name" placeholder="Zockelo"
                 value={get_in(@tenant.config, ["app_name"]) || ""}
                 class="input input-bordered w-full" />
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Data retention period (days)</label>
          <input type="number" name="retention_period_days" min="90"
                 value={get_in(@tenant.config, ["retention_period_days"]) || 730}
                 class="input input-bordered w-full" />
        </div>

        <.button type="submit">Save Config</.button>
      </form>
    </div>
    """
  end

  defp render_invite_links(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="text-lg font-semibold">Shareable Invite Links</h2>

      <%= if @invite_links == [] do %>
        <div class="rounded-lg border-2 border-dashed border-gray-300 p-8 text-center">
          <p class="text-gray-500 mb-4">No invite links yet.</p>
          <button phx-click="generate_invite_link" class="btn btn-primary">Generate invite link</button>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for link <- @invite_links do %>
            <div class="rounded-lg border border-gray-200 p-4 space-y-3">
              <div class="flex items-start justify-between gap-4">
                <div class="flex-1">
                  <p class="text-sm font-medium mb-1">Invite URL</p>
                  <code class="text-xs bg-gray-100 rounded px-2 py-1 break-all">
                    <%= invite_url(@tenant.slug, link.token) %>
                  </code>
                </div>
                <button onclick={"navigator.clipboard.writeText('#{invite_url(@tenant.slug, link.token)}')"}
                        class="btn btn-sm btn-ghost">Copy</button>
              </div>

              <div class="flex items-center gap-4">
                <div class="flex-1">
                  <label class="text-xs text-gray-500">Expires at</label>
                  <input type="datetime-local" phx-blur="set_invite_expiry"
                         phx-value-link_id={link.id}
                         value={format_datetime(link.expires_at)}
                         class="input input-sm input-bordered w-full" />
                </div>
                <button phx-click="rotate_invite_link" phx-value-link_id={link.id}
                        data-confirm="Rotate invite link? The current link will stop working immediately."
                        class="btn btn-sm btn-warning">Rotate</button>
              </div>
            </div>
          <% end %>
        </div>

        <button phx-click="generate_invite_link" class="btn btn-outline">Generate new link</button>
      <% end %>
    </div>
    """
  end

  defp render_gdpr(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold mb-4">GDPR Key Deletion Audit Log</h2>

      <%= if @gdpr_log == [] do %>
        <p class="text-gray-500">No deletion records.</p>
      <% else %>
        <div class="overflow-hidden rounded-lg border border-gray-200">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Player ID</th>
                <th class="px-4 py-3 text-left text-sm font-medium text-gray-500">Key Deleted At</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white">
              <%= for entry <- @gdpr_log do %>
                <tr>
                  <td class="px-4 py-3 font-mono text-sm"><%= entry.player_id %></td>
                  <td class="px-4 py-3 text-sm"><%= entry.deleted_at %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_deletion(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="text-lg font-semibold text-red-700">Danger Zone</h2>

      <%= if @tenant.status == "active" do %>
        <div class="rounded-lg border border-red-200 bg-red-50 p-6">
          <h3 class="font-semibold text-red-800 mb-2">Delete This League</h3>
          <p class="text-sm text-red-700 mb-4">
            Initiates the league deletion process. A 48-hour grace period applies during which the deletion can be cancelled.
            After confirmation, all player data will be permanently crypto-shredded.
          </p>
          <button phx-click="request_deletion"
                  data-confirm="Initiate deletion of this league? A 48-hour grace period applies."
                  class="btn btn-error">
            Initiate Deletion
          </button>
        </div>
      <% end %>

      <%= if @tenant.status == "deletion_pending" do %>
        <div class="rounded-lg border border-orange-200 bg-orange-50 p-6">
          <h3 class="font-semibold text-orange-800 mb-2">Deletion Pending</h3>
          <p class="text-sm text-orange-700 mb-4">
            This league is scheduled for deletion. You can still cancel during the grace period.
          </p>
          <button phx-click="cancel_deletion" class="btn btn-warning">
            Cancel Deletion
          </button>
        </div>
      <% end %>

      <%= if @tenant.status == "deleted" do %>
        <p class="text-gray-500">This league has been deleted.</p>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp load_tab(socket, "players") do
    tenant_id = socket.assigns.tenant.id

    socket
    |> assign(:active_players, Players.list_active_players(tenant_id))
    |> assign(:invited_players, Players.list_invited_players(tenant_id))
    |> assign(:confirm_delete_player_id, nil)
  end

  defp load_tab(socket, "config"), do: socket

  defp load_tab(socket, "invite_links") do
    tenant_id = socket.assigns.tenant.id
    links = Repo.all(from l in InviteLink,
      where: l.tenant_id == ^tenant_id and is_nil(l.revoked_at),
      order_by: [desc: l.inserted_at])
    assign(socket, :invite_links, links)
  end

  defp load_tab(socket, "gdpr") do
    tenant_id = socket.assigns.tenant.id
    log = Repo.all(from g in GdprKeyDeletion,
      where: g.tenant_id == ^tenant_id,
      order_by: [desc: g.deleted_at])
    assign(socket, :gdpr_log, log)
  end

  defp load_tab(socket, "disputed_games") do
    tenant_id = socket.assigns.tenant.id
    assign(socket, :disputed_games, Games.list_disputed_games(tenant_id))
  end

  defp load_tab(socket, "deletion"), do: socket

  defp load_tab(socket, _), do: socket

  defp render_disputed_games(assigns) do
    ~H"""
    <div class="space-y-4">
      <h2 class="text-lg font-semibold">Disputed Games</h2>
      <%= if @disputed_games == [] do %>
        <p class="text-gray-500">No disputed games.</p>
      <% else %>
        <div class="space-y-3">
          <%= for game <- @disputed_games do %>
            <div class="rounded-lg border border-red-200 bg-red-50 p-4">
              <div class="flex items-center justify-between mb-2">
                <span class="text-xs font-mono text-gray-500"><%= game.id %></span>
                <span class="text-xs text-gray-400">
                  <%= Calendar.strftime(game.logged_at, "%Y-%m-%d %H:%M") %>
                </span>
              </div>
              <div class="flex gap-2 mt-2">
                <button phx-click="reinstate_game" phx-value-game_id={game.id}
                        class="btn btn-success btn-xs">Reinstate</button>
                <button phx-click="void_game" phx-value-game_id={game.id}
                        class="btn btn-error btn-xs">Void</button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :tab, :string, required: true
  attr :current, :string, required: true
  attr :slug, :string, required: true
  slot :inner_block, required: true

  defp tab_link(assigns) do
    active = assigns.tab == assigns.current

    assigns = assign(assigns, :active, active)

    ~H"""
    <.link patch={~p"/#{@slug}/admin?tab=#{@tab}"}
           class={[
             "pb-2 text-sm font-medium border-b-2 transition-colors",
             if(@active, do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700")
           ]}>
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  defp invite_url(slug, token) do
    ZockeloWeb.Endpoint.url() <> "/#{slug}/join/#{token}"
  end

  defp format_datetime(nil), do: ""
  defp format_datetime(%DateTime{} = dt) do
    dt
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
    |> String.replace("Z", "")
    |> String.replace_suffix(":00", "")
  end
end
