defmodule ZockeloWeb.EmailChangeLive do
  @moduledoc "Email change confirmation: /auth/email-change?token=..."
  use ZockeloWeb, :live_view

  on_mount {ZockeloWeb.Live.AuthHooks, :load_session}

  alias Zockelo.{Auth, Players}

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    result =
      case Auth.verify_email_change_token(token) do
        {:ok, player_id, tenant_id, new_email_encrypted} ->
          Players.confirm_email_change(player_id, tenant_id, new_email_encrypted)

        {:error, reason} ->
          {:error, reason}
      end

    {:ok,
     socket
     |> assign(:page_title, "Confirm Email Change")
     |> assign(:result, result)}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Confirm Email Change")
     |> assign(:result, {:error, :missing_token})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 p-6">
      <div class="max-w-sm w-full text-center space-y-4">
        <%= case @result do %>
          <% :ok -> %>
            <div class="rounded-lg bg-green-50 border border-green-200 p-4 text-green-700">
              <p class="font-semibold">Email updated successfully.</p>
            </div>

          <% {:error, _} -> %>
            <div class="rounded-lg bg-red-50 border border-red-200 p-4 text-red-700">
              <p class="font-semibold">This link is invalid or has expired.</p>
            </div>
        <% end %>
        <.link navigate={~p"/"} class="text-sm text-blue-600 hover:underline">← Home</.link>
      </div>
    </div>
    """
  end
end
