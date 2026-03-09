defmodule ZockeloWeb.Admin.SuperAdminsLive do
  @moduledoc "Super admin management: grant and revoke super admin role."
  use ZockeloWeb, :live_view

  alias Zockelo.SuperAdmins

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:super_admins, load_with_emails())
     |> assign(:add_form, to_form(%{"player_id" => "", "email" => ""}))
     |> assign(:page_title, "Super Admins")}
  end

  @impl true
  def handle_event("grant", %{"player_id" => pid, "email" => email}, socket) do
    case SuperAdmins.create_super_admin(pid, email) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Super admin granted.")
         |> assign(:super_admins, load_with_emails())}

      {:error, :already_exists} ->
        {:noreply, put_flash(socket, :error, "Already a super admin.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("revoke", %{"player_id" => player_id}, socket) do
    remaining = SuperAdmins.list_super_admins()

    if length(remaining) <= 1 do
      {:noreply, put_flash(socket, :error, "Cannot remove the last super admin.")}
    else
      case SuperAdmins.remove_super_admin(player_id) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:info, "Super admin revoked.")
           |> assign(:super_admins, load_with_emails())}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "Not found.")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6 space-y-8">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Super Admins</h1>
        <.link navigate={~p"/admin"} class="text-sm text-blue-600 hover:underline">← Back</.link>
      </div>

      <section>
        <h2 class="text-lg font-semibold mb-3">Current Super Admins</h2>
        <%= if @super_admins == [] do %>
          <p class="text-gray-500">None.</p>
        <% else %>
          <div class="space-y-2">
            <%= for {sa, email} <- @super_admins do %>
              <div class="flex items-center justify-between rounded-lg border p-3">
                <div>
                  <p class="font-mono text-sm"><%= sa.player_id %></p>
                  <p class="text-sm text-gray-500"><%= email %></p>
                </div>
                <button phx-click="revoke" phx-value-player_id={sa.player_id}
                        class="btn btn-sm btn-error">Revoke</button>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Grant Super Admin</h2>
        <.form for={@add_form} phx-submit="grant" class="space-y-3">
          <.input field={@add_form[:player_id]} label="Player UUID" type="text" placeholder="00000000-0000-0000-0000-000000000000" required />
          <.input field={@add_form[:email]} label="Email" type="email" placeholder="admin@example.com" required />
          <.button type="submit">Grant</.button>
        </.form>
      </section>
    </div>
    """
  end

  defp load_with_emails do
    SuperAdmins.list_super_admins()
    |> Enum.map(fn sa ->
      email =
        case SuperAdmins.decrypt_email(sa) do
          {:ok, e} -> e
          _ -> "[encrypted]"
        end
      {sa, email}
    end)
  end
end
