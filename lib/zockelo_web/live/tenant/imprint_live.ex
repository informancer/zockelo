defmodule ZockeloWeb.Tenant.ImprintLive do
  @moduledoc "Public imprint page: /:tenant_slug/imprint (no auth required)."
  use ZockeloWeb, :live_view

  alias Zockelo.Tenants

  @impl true
  def mount(%{"tenant_slug" => slug}, _session, socket) do
    tenant = Tenants.get_tenant_by_slug(slug)

    if is_nil(tenant) do
      {:ok, redirect(socket, to: ~p"/")}
    else
      config = tenant.config || %{}

      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:config, config)
       |> assign(:page_title, "Imprint — #{app_name(config)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 space-y-6">
      <h1 class="text-2xl font-bold">Imprint</h1>

      <section class="space-y-1 text-sm">
        <p class="font-semibold"><%= app_name(@config) %></p>
        <%= if @config["imprint_street"] do %>
          <p><%= @config["imprint_street"] %></p>
        <% end %>
        <%= if @config["imprint_postal_code"] || @config["imprint_city"] do %>
          <p>
            <%= [@config["imprint_postal_code"], @config["imprint_city"]] |> Enum.reject(&is_nil/1) |> Enum.join(" ") %>
          </p>
        <% end %>
        <%= if @config["imprint_country_code"] do %>
          <p><%= @config["imprint_country_code"] %></p>
        <% end %>
      </section>

      <%= if !@config["imprint_street"] and !@config["imprint_city"] do %>
        <p class="text-gray-500 text-sm italic">Imprint information not yet configured.</p>
      <% end %>

      <p class="text-sm text-gray-500">
        <.link navigate={~p"/#{@tenant.slug}/privacy"} class="underline">Privacy Notice</.link>
      </p>
    </div>
    """
  end

  defp app_name(%{"app_name" => name}) when is_binary(name) and name != "", do: name
  defp app_name(_), do: "Zockelo"
end
