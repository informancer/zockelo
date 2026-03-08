defmodule ZockeloWeb.ManifestController do
  use ZockeloWeb, :controller

  @doc """
  Serves a per-tenant Web App Manifest (manifest.json).

  When a tenant slug is present in the path, the manifest uses the tenant's
  `app_name` for `name` and `short_name`. Falls back to the system default
  when no tenant context is available.
  """
  def show(conn, %{"tenant_slug" => slug}) do
    # Tenant context will be loaded from the DB once tenants are implemented.
    # For now, derive a human-readable name from the slug.
    app_name = slug |> String.replace("-", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1)
    render_manifest(conn, app_name, slug)
  end

  def show(conn, _params) do
    render_manifest(conn, "Zockelo", "")
  end

  defp render_manifest(conn, app_name, _slug) do
    manifest = %{
      name: app_name,
      short_name: app_name,
      description: "Foosball Elo tracker",
      start_url: "/",
      display: "standalone",
      background_color: "#ffffff",
      theme_color: "#f97316",
      icons: [
        %{src: "/images/icon-192.png", sizes: "192x192", type: "image/png"},
        %{src: "/images/icon-512.png", sizes: "512x512", type: "image/png"}
      ]
    }

    conn
    |> put_resp_content_type("application/manifest+json")
    |> json(manifest)
  end
end
