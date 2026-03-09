defmodule ZockeloWeb.Tenant.GamesLive do
  @moduledoc "Game history for a tenant: /:tenant_slug/games"
  use ZockeloWeb, :live_view

  alias Zockelo.Games

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    current_user = socket.assigns.current_user

    # Load all active players for the player filter dropdown
    active_players = Games.list_active_players_with_ratings(tenant.id)

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:current_user, current_user)
     |> assign(:page_title, "Games")
     |> assign(:active_players, active_players)
     |> assign(:filter_player_id, nil)
     |> assign(:filter_date_from, nil)
     |> assign(:filter_date_to, nil)
     |> assign(:page, 0)
     |> assign(:pending_games, Games.list_pending_games(tenant.id))
     |> assign(:result, %{games: [], page: 0, page_size: 20, total: 0})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    player_id = params["player"]
    date_from = parse_date(params["from"])
    date_to = parse_date(params["to"])
    page = parse_page(params["page"])

    {:noreply,
     socket
     |> assign(:filter_player_id, player_id)
     |> assign(:filter_date_from, date_from)
     |> assign(:filter_date_to, date_to)
     |> assign(:page, page)
     |> load_games_page(player_id, date_from, date_to, page)}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("confirm_game", %{"game_id" => game_id}, socket) do
    player_id = socket.assigns.current_user.player_id

    case Games.confirm_game(game_id, player_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Game confirmed.")
         |> assign(:pending_games, Games.list_pending_games(socket.assigns.tenant.id))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("dispute_game", %{"game_id" => game_id}, socket) do
    player_id = socket.assigns.current_user.player_id

    case Games.dispute_game(game_id, player_id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Game disputed.")
         |> assign(:pending_games, Games.list_pending_games(socket.assigns.tenant.id))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("apply_filters", params, socket) do
    player_id = nilify(params["player"])
    date_from = nilify(params["from"])
    date_to = nilify(params["to"])

    query =
      %{}
      |> maybe_put("player", player_id)
      |> maybe_put("from", date_from)
      |> maybe_put("to", date_to)

    {:noreply, push_patch(socket, to: ~p"/#{socket.assigns.tenant.slug}/games?#{query}")}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/#{socket.assigns.tenant.slug}/games")}
  end

  def handle_event("next_page", _params, socket) do
    result = socket.assigns.result
    if has_next_page?(result) do
      {:noreply, push_patch(socket, to: page_path(socket, result.page + 1))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("prev_page", _params, socket) do
    page = socket.assigns.page
    if page > 0 do
      {:noreply, push_patch(socket, to: page_path(socket, page - 1))}
    else
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-16 sm:pb-0">
      <ZockeloWeb.NavComponent.tenant_nav tenant={@tenant} current_user={@current_user} active="games" />

      <div class="max-w-2xl mx-auto p-4 sm:p-6 space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Games</h1>
          <.link navigate={~p"/#{@tenant.slug}/games/new"} class="btn btn-primary btn-sm">
            Log a Game
          </.link>
        </div>

        <!-- Filters -->
        <form phx-submit="apply_filters" class="flex flex-wrap gap-3 items-end">
          <div>
            <label class="block text-xs text-gray-500 mb-1">Player</label>
            <select name="player" class="select select-bordered select-sm">
              <option value="">All players</option>
              <%= for {profile, _rating} <- @active_players do %>
                <option value={profile.player_id}
                        selected={profile.player_id == @filter_player_id}>
                  <%= player_name(profile) %>
                </option>
              <% end %>
            </select>
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">From</label>
            <input type="date" name="from" value={@filter_date_from} class="input input-bordered input-sm" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">To</label>
            <input type="date" name="to" value={@filter_date_to} class="input input-bordered input-sm" />
          </div>
          <button type="submit" class="btn btn-outline btn-sm">Filter</button>
          <%= if @filter_player_id || @filter_date_from || @filter_date_to do %>
            <button type="button" phx-click="reset_filters" class="btn btn-ghost btn-sm">Clear</button>
          <% end %>
        </form>

        <!-- Pending games -->
        <%= if @pending_games != [] do %>
          <section>
            <h2 class="text-lg font-semibold mb-3 text-amber-700">
              Pending Confirmation (<%= length(@pending_games) %>)
            </h2>
            <div class="space-y-2">
              <%= for game <- @pending_games do %>
                <div class="rounded-lg border border-amber-200 bg-amber-50 p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-xs font-medium text-amber-700 bg-amber-100 px-2 py-0.5 rounded-full">
                      pending
                    </span>
                    <span class="text-xs text-gray-400">
                      <%= Calendar.strftime(game.logged_at, "%Y-%m-%d %H:%M") %>
                    </span>
                  </div>
                  <%= if can_act_on_game?(game, @current_user) do %>
                    <div class="flex gap-2 mt-2">
                      <button phx-click="confirm_game" phx-value-game_id={game.id}
                              class="btn btn-success btn-xs">Confirm</button>
                      <button phx-click="dispute_game" phx-value-game_id={game.id}
                              class="btn btn-error btn-xs">Dispute</button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </section>
        <% end %>

        <!-- Game history -->
        <section>
          <h2 class="text-lg font-semibold mb-3">Game History</h2>
          <%= if @result.games == [] do %>
            <div class="text-center py-12 text-gray-500">
              <p class="text-lg">No games found.</p>
              <.link navigate={~p"/#{@tenant.slug}/games/new"}
                     class="text-blue-600 hover:underline mt-2 inline-block">
                Log your first game →
              </.link>
            </div>
          <% else %>
            <div class="space-y-2">
              <%= for game <- @result.games do %>
                <div class="rounded-lg border bg-white p-4 shadow-sm">
                  <div class="flex items-center justify-between">
                    <span class={"text-xs font-medium px-2 py-0.5 rounded-full #{status_class(game.status)}"}>
                      <%= game.status %>
                    </span>
                    <span class="text-xs text-gray-400">
                      <%= Calendar.strftime(game.logged_at, "%Y-%m-%d %H:%M") %>
                    </span>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Pagination -->
            <div class="flex items-center justify-between pt-4 text-sm">
              <button phx-click="prev_page" disabled={@page == 0}
                      class="btn btn-ghost btn-sm">← Prev</button>
              <span class="text-gray-500">
                <%= @page * @result.page_size + 1 %>–<%= min((@page + 1) * @result.page_size, @result.total) %>
                of <%= @result.total %>
              </span>
              <button phx-click="next_page" disabled={not has_next_page?(@result)}
                      class="btn btn-ghost btn-sm">Next →</button>
            </div>
          <% end %>
        </section>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp load_games_page(socket, player_id, date_from, date_to, page) do
    tenant_id = socket.assigns.tenant.id

    result =
      Games.list_games_page(tenant_id,
        player_id: player_id,
        date_from: date_from,
        date_to: date_to,
        page: page
      )

    assign(socket, :result, result)
  end

  defp has_next_page?(%{page: page, page_size: ps, total: total}) do
    (page + 1) * ps < total
  end

  defp page_path(socket, new_page) do
    query =
      %{}
      |> maybe_put("player", socket.assigns.filter_player_id)
      |> maybe_put("from", socket.assigns.filter_date_from)
      |> maybe_put("to", socket.assigns.filter_date_to)
      |> maybe_put("page", if(new_page > 0, do: new_page, else: nil))

    ~p"/#{socket.assigns.tenant.slug}/games?#{query}"
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp nilify(""), do: nil
  defp nilify(v), do: v

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp parse_page(nil), do: 0
  defp parse_page(""), do: 0

  defp parse_page(str) do
    case Integer.parse(str) do
      {n, ""} when n >= 0 -> n
      _ -> 0
    end
  end

  defp can_act_on_game?(game, current_user) do
    is_participant =
      current_user.player_id in (game.team1_players || []) or
        current_user.player_id in (game.team2_players || [])

    is_admin = current_user.role in ["tenant_admin", "super_admin"]
    is_participant or is_admin
  end

  defp player_name(%{encrypted_name: enc, player_id: pid}) when not is_nil(enc) do
    case Zockelo.Crypto.decrypt_field(pid, enc) do
      {:ok, name} -> name
      _ -> Zockelo.Crypto.deleted_player_name()
    end
  end

  defp player_name(%{player_id: pid}), do: "Player #{String.slice(pid, 0, 6)}"

  defp status_class("confirmed"), do: "bg-green-100 text-green-700"
  defp status_class("pending"), do: "bg-yellow-100 text-yellow-700"
  defp status_class("disputed"), do: "bg-red-100 text-red-700"
  defp status_class("voided"), do: "bg-gray-100 text-gray-500"
  defp status_class(_), do: "bg-gray-100 text-gray-600"
end
