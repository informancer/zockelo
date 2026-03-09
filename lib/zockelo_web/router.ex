defmodule ZockeloWeb.Router do
  use ZockeloWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZockeloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ZockeloWeb.Plugs.LoadSessionPlug
  end

  # Requires an active session; redirects to login otherwise.
  pipeline :require_auth do
    plug ZockeloWeb.Plugs.RequireAuthPlug
  end

  # Requires the player to be a member of the tenant in the URL slug.
  pipeline :require_tenant do
    plug ZockeloWeb.Plugs.RequireTenantPlug
  end

  # Requires super admin privileges.
  pipeline :require_super_admin do
    plug ZockeloWeb.Plugs.RequireSuperAdminPlug
  end

  # Requires tenant admin or super admin role.
  pipeline :require_tenant_admin do
    plug ZockeloWeb.Plugs.RequireTenantAdminPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # PWA service worker — must be served from root scope for max-scope registration.
  scope "/", ZockeloWeb do
    pipe_through :api
    get "/sw.js", ServiceWorkerController, :show
  end

  scope "/", ZockeloWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/manifest.json", ManifestController, :show
    get "/:tenant_slug/manifest.json", ManifestController, :show
  end

  # Tenant admin panel — /:tenant_slug/admin
  scope "/:tenant_slug", ZockeloWeb.TenantAdmin do
    pipe_through [:browser, :require_auth, :require_tenant, :require_tenant_admin]

    live "/admin", AdminLive
  end

  # Super admin panel — /admin/*
  scope "/admin", ZockeloWeb.Admin do
    pipe_through [:browser, :require_super_admin]

    live "/", IndexLive
    live "/tenants/new", TenantNewLive
    live "/tenants/requests", TenantRequestsLive
    live "/tenants/:tenant_id", TenantDetailLive
    live "/config", SystemConfigLive
    live "/super-admins", SuperAdminsLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZockeloWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:zockelo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ZockeloWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
