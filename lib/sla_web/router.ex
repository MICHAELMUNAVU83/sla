defmodule SlaWeb.Router do
  use SlaWeb, :router

  import SlaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SlaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SlaWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", SlaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :app,
      on_mount: [{SlaWeb.UserAuth, :require_authenticated}] do
      live "/clients", ClientLive.Index, :index
      live "/clients/new", ClientLive.Index, :new
      live "/clients/:id", ClientLive.Show, :show
      live "/clients/:id/edit", ClientLive.Show, :edit
      live "/matters", MatterLive.Index, :index
      live "/matters/new", MatterLive.Index, :new
      live "/matters/:id", MatterLive.Show, :show
      live "/matters/:id/edit", MatterLive.Show, :edit
      live "/diary", DiaryLive.Index, :index
      live "/calendar", CalendarLive.Index, :index
      live "/intake", IntakeLive.Index, :index
      live "/notifications", NotificationLive.Index, :index
      live "/documents", DocumentLive.Index, :index
      live "/documents/:id", DocumentLive.Show, :show
      live "/billing", BillingLive.Index, :index
      live "/reports", ReportsLive.Index, :index
      live "/intelligence", IntelligenceLive.Index, :index
      live "/integrations", IntegrationLive.Index, :index
      live "/allocation", AllocationLive.Index, :index
      live "/manual", ManualLive.Index, :index
      live "/admin/users", AdminUserLive.Index, :index
    end

    get "/documents/:id/download", DocumentFileController, :download
    get "/documents/:id/preview", DocumentFileController, :preview
  end

  scope "/webhooks", SlaWeb do
    pipe_through :api
    post "/:provider", IntegrationWebhookController, :receive
  end

  scope "/portal", SlaWeb do
    pipe_through :browser

    live_session :client_portal do
      live "/log-in", PortalLive.Login, :new
      live "/", PortalLive.Index, :index
    end

    post "/log-in", PortalSessionController, :create
    delete "/log-out", PortalSessionController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", SlaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sla, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SlaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SlaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SlaWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SlaWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SlaWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
