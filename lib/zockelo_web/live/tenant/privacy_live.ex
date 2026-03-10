defmodule ZockeloWeb.Tenant.PrivacyLive do
  @moduledoc "System-generated privacy notice: /:tenant_slug/privacy (no auth required)."
  use ZockeloWeb, :live_view

  alias Zockelo.{Tenants, Legal.SupervisoryAuthority}

  @impl true
  def mount(%{"tenant_slug" => slug}, _session, socket) do
    tenant = Tenants.get_tenant_by_slug(slug)

    if is_nil(tenant) do
      {:ok, redirect(socket, to: ~p"/")}
    else
      config = tenant.config || %{}
      authority = SupervisoryAuthority.lookup(config["imprint_country_code"])
      retention_days = config["retention_period_days"] || 730

      addendum_html =
        case config["privacy_addendum"] do
          nil -> nil
          "" -> nil
          md -> render_markdown(md)
        end

      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:config, config)
       |> assign(:authority, authority)
       |> assign(:retention_days, retention_days)
       |> assign(:addendum_html, addendum_html)
       |> assign(:page_title, "Privacy Notice — #{app_name(config)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 space-y-6 text-sm leading-relaxed">
      <h1 class="text-2xl font-bold">Privacy Notice</h1>
      <p class="text-gray-500">Last updated: automatically generated from current configuration.</p>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">1. Controller</h2>
        <p>
          The controller responsible for data processing is the operator of this
          <strong><%= app_name(@config) %></strong> instance.
        </p>
        <%= if @config["imprint_street"] do %>
          <p>
            <%= @config["imprint_street"] %>,
            <%= [@config["imprint_postal_code"], @config["imprint_city"]] |> Enum.reject(&is_nil/1) |> Enum.join(" ") %>,
            <%= @config["imprint_country_code"] %>
          </p>
        <% end %>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">2. Data Processed</h2>
        <ul class="list-disc list-inside space-y-1">
          <li>Email address (used for authentication and notifications)</li>
          <li>Display name (chosen by you on first login)</li>
          <li>Game participation and results (Elo ratings, win/loss history)</li>
          <li>Session token (stored in a cookie, see §5)</li>
          <li>Login timestamps (for inactivity tracking and GDPR retention)</li>
        </ul>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">3. Purpose and Legal Basis</h2>
        <p>
          Your data is processed solely to operate the foosball Elo rating tracker:
          authenticating you, recording game results, and displaying the leaderboard.
          Legal basis: Art. 6(1)(b) GDPR (performance of a contract / legitimate interest).
        </p>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">4. Retention</h2>
        <p>
          Personal data is retained for <strong><%= @retention_days %> days</strong> after your last login.
          You will receive a warning email 30 days before deletion.
          You may also request immediate deletion via the account settings page.
        </p>
        <p>
          Game participation records and Elo history are retained in anonymised form
          after account deletion (no personal data, only UUID references).
        </p>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">5. Cookies</h2>
        <p>This application uses one essential session cookie:</p>
        <ul class="list-disc list-inside">
          <li><strong>_zockelo_key</strong> — stores your session identifier. Required for authentication. HttpOnly, SameSite=Lax. Expires when your session ends or after 8 hours of inactivity.</li>
        </ul>
        <p>No tracking cookies, analytics, or third-party cookies are used.</p>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">6. Recipients</h2>
        <p>No third-party recipients. Your data is not shared with any external parties.</p>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">7. Third-Country Transfers</h2>
        <p>No transfers to third countries outside the EU/EEA take place.</p>
      </section>

      <section class="space-y-2">
        <h2 class="font-semibold text-base">8. Your Rights</h2>
        <p>Under GDPR you have the right to: access, rectification, erasure, restriction,
        portability, and objection. To exercise these rights, contact the controller above
        or use the data export and account deletion features in your profile settings.</p>
        <p>
          You also have the right to lodge a complaint with a supervisory authority (Art. 13(2)(d) GDPR).
        </p>
        <%= case @authority do %>
          <% {:ok, %{germany_note: true} = auth} -> %>
            <p>
              The competent federal authority is the
              <a href={auth.url} class="underline" target="_blank" rel="noopener noreferrer"><%= auth.name %></a>.
              Depending on the location of the controller, a competent Länder supervisory authority
              may also have jurisdiction — please refer to the BfDI website for the full list.
            </p>
          <% {:ok, auth} -> %>
            <p>
              The competent supervisory authority is the
              <a href={auth.url} class="underline" target="_blank" rel="noopener noreferrer"><%= auth.name %></a>.
            </p>
          <% :unknown -> %>
            <p>
              Please contact the controller to identify the competent supervisory authority
              in your country.
            </p>
        <% end %>
      </section>

      <%= if @addendum_html do %>
        <section class="space-y-2 border-t pt-4">
          <h2 class="font-semibold text-base">9. Additional Information</h2>
          <div class="prose prose-sm max-w-none">
            <%= raw(@addendum_html) %>
          </div>
        </section>
      <% end %>

      <p class="text-gray-400 text-xs pt-4 border-t">
        <.link navigate={~p"/#{@tenant.slug}/imprint"} class="underline">Imprint</.link>
      </p>
    </div>
    """
  end

  defp app_name(%{"app_name" => name}) when is_binary(name) and name != "", do: name
  defp app_name(_), do: "Zockelo"

  defp render_markdown(md) do
    case Earmark.as_html(md, escape: false) do
      {:ok, html, _} -> HtmlSanitizeEx.basic_html(html)
      _ -> HtmlSanitizeEx.basic_html(md)
    end
  end
end
