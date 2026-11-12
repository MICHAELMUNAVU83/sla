defmodule SlaWeb.PortalLive.Login do
  use SlaWeb, :live_view

  def mount(_, _, socket),
    do: {:ok, assign(socket, form: to_form(%{"email" => "", "password" => ""}, as: :portal))}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main id="portal-login" class="auth-shell auth-shell-portal">
        <section class="auth-story" aria-label="Sichangi Law Alliance client portal">
          <.link navigate={~p"/"} class="auth-brand"><img
            src={~p"/images/logo-sla-wordmark.png"}
            alt="Sichangi Law Alliance"
          /></.link>
          <div class="auth-story-copy">
            <p class="auth-kicker">Client portal</p><h1>Your legal work.<br />Clearly connected.</h1><p>
              Review matter progress, exchange documents, and stay close to your SLA team in one secure place.
            </p>
          </div>
          <p class="auth-story-foot">Confidential · Secure · Connected</p>
        </section>
        <section class="auth-panel">
          <div class="auth-card">
            <.link navigate={~p"/"} class="auth-back"><.icon name="hero-arrow-left" class="size-4" />
            Back to the SLA website</.link>
            <p class="auth-kicker">SLA client portal</p><h2>Welcome back</h2><p class="auth-intro">
              Sign in to view your matters and shared documents.
            </p>
            <.form for={@form} id="portal-login-form" action={~p"/portal/log-in"} class="auth-form">
              <.input field={@form[:email]} type="email" label="Email" autocomplete="email" required />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
                required
              />
              <.button id="portal-login-button" class="auth-primary-button w-full">Sign in securely
              <.icon name="hero-arrow-right" class="size-4" /></.button>
            </.form>
            <div class="auth-security">
              <.icon name="hero-lock-closed" class="size-4" /><span>Your connection and portal activity are protected.</span>
            </div>
          </div>
        </section>
      </main>
    </Layouts.app>
    """
  end
end
