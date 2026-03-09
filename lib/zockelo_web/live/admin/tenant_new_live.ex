defmodule ZockeloWeb.Admin.TenantNewLive do
  @moduledoc "Super admin form for creating a tenant directly."
  use ZockeloWeb, :live_view

  alias Zockelo.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form, to_form(%{"slug" => "", "name" => ""}))
     |> assign(:page_title, "New League")}
  end

  @impl true
  def handle_event("validate", %{"tenant" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params, as: "tenant"))}
  end

  def handle_event("save", %{"tenant" => params}, socket) do
    case Tenants.register_tenant(params) do
      {:ok, _tenant_id} ->
        {:noreply,
         socket
         |> put_flash(:info, "League created!")
         |> push_navigate(to: ~p"/admin")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">New League</h1>

      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
        <div>
          <label class="block text-sm font-medium mb-1">League Name</label>
          <.input field={@form[:name]} type="text" placeholder="Acme FC" required />
        </div>
        <div>
          <label class="block text-sm font-medium mb-1">Slug</label>
          <.input field={@form[:slug]} type="text" placeholder="acme-fc" required />
          <p class="text-xs text-gray-500 mt-1">Used in URLs: /acme-fc/leaderboard</p>
        </div>
        <div class="flex gap-3 pt-2">
          <.button type="submit">Create League</.button>
          <.link navigate={~p"/admin"} class="btn">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end
end
