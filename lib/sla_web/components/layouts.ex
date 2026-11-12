defmodule SlaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SlaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="app-frame">
      <aside :if={@current_scope && @current_scope.user} class="sidebar">
        <.link navigate={~p"/matters"} class="brand-lockup"><img
          src={~p"/images/logo-sla-wordmark.png"}
          alt="Sichangi Law Alliance"
        /><span class="sr-only">Sichangi Law Alliance</span></.link>
        <nav class="side-nav" aria-label="Primary navigation">
          <.link id="nav-clients" navigate={~p"/clients"}><.icon
            name="hero-user-group"
            class="size-5"
          /><span>Client management</span></.link>
          <.link id="nav-matters" navigate={~p"/matters"}><.icon name="hero-scale" class="size-5" /><span>Case management</span></.link>
          <.link id="nav-diary" navigate={~p"/diary"}><.icon name="hero-bell-alert" class="size-5" /><span>Bring-up system</span></.link>
          <.link id="nav-calendar" navigate={~p"/calendar"}><.icon
            name="hero-calendar"
            class="size-5"
          /><span>Calendar & deadlines</span></.link>
          <.link id="nav-documents" navigate={~p"/documents"}><.icon
            name="hero-document-text"
            class="size-5"
          /><span>Document management</span></.link>
          <.link id="nav-billing" navigate={~p"/billing"}><.icon name="hero-banknotes" class="size-5" /><span>Legal fees</span></.link>
          <.link id="nav-allocation" navigate={~p"/allocation"}><.icon
            name="hero-user-circle"
            class="size-5"
          /><span>Work allocation</span></.link>
          <span class="nav-label">More</span>
          <.link id="nav-intake" navigate={~p"/intake"}><.icon
            name="hero-clipboard-document-check"
            class="size-5"
          /><span>Intake & compliance</span></.link>
          <.link id="nav-reports" navigate={~p"/reports"}><.icon name="hero-chart-bar" class="size-5" /><span>Accounts & reports</span></.link>
          <.link id="nav-intelligence" navigate={~p"/intelligence"}><.icon
            name="hero-sparkles"
            class="size-5"
          /><span>AI workspace</span></.link>
          <.link id="nav-integrations" navigate={~p"/integrations"}><.icon
            name="hero-puzzle-piece"
            class="size-5"
          /><span>Integrations</span></.link>
          <.link id="nav-manual" navigate={~p"/manual"}><.icon name="hero-book-open" class="size-5" /><span>User manual</span></.link>
          <.link
            :if={Sla.Policy.admin?(@current_scope)}
            id="nav-admin-users"
            navigate={~p"/admin/users"}
          ><.icon name="hero-shield-check" class="size-5" /><span>Team access</span></.link>
        </nav>
        <div class="sidebar-user">
          <div class="avatar-mark">
            {@current_scope.user.email |> String.first() |> String.upcase()}
          </div><div class="min-w-0">
            <p>{@current_scope.user.name || @current_scope.user.email}</p><span>{@current_scope.user.role}</span>
          </div><.link href={~p"/users/log-out"} method="delete" aria-label="Log out"><.icon
            name="hero-arrow-right-start-on-rectangle"
            class="size-5"
          /></.link>
        </div>
      </aside>
      <div class={
        if(@current_scope && @current_scope.user, do: "main-column", else: "public-main-column")
      }>
        <header :if={@current_scope && @current_scope.user} class="topbar">
          <div><span class="pulse-dot"></span> Practice operations</div><div class="topbar-tools">
            <.link id="notification-bell" navigate={~p"/notifications"} class="notification-bell"><.icon
              name="hero-bell"
              class="size-5"
            /><span :if={Sla.Tracker.unread_count(@current_scope.user.id) > 0}>{Sla.Tracker.unread_count(
              @current_scope.user.id
            )}</span></.link><.link navigate={~p"/users/settings"} class="topbar-action"><.icon
              name="hero-cog-6-tooth"
              class="size-5"
            /><span class="sr-only">Account settings</span></.link>
          </div>
        </header><main class={
          if(@current_scope && @current_scope.user, do: "app-content", else: "public-content")
        }>
          <div class={
            if(@current_scope && @current_scope.user,
              do: "w-[96%] mx-auto",
              else: "public-content-inner"
            )
          }>
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
