defmodule SlaWeb.PortalLive.Login do
  use SlaWeb, :live_view

  def mount(_, _, socket),
    do: {:ok, assign(socket, form: to_form(%{"email" => "", "password" => ""}, as: :portal))}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main id="portal-login" class="mx-auto max-w-md py-16">
        <section class="content-card">
          <p class="text-xs font-bold uppercase tracking-[.2em] text-amber-700">SLA Client Portal</p>
          <h1 class="mt-2 text-3xl font-bold text-slate-950">Welcome back</h1>
          <.form for={@form} id="portal-login-form" action={~p"/portal/log-in"} class="mt-8 space-y-5">
            <.input field={@form[:email]} type="email" label="Email" autocomplete="email" required />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
              required
            />
            <.button id="portal-login-button" class="btn-primary w-full">Sign in securely</.button>
          </.form>
        </section>
      </main>
    </Layouts.app>
    """
  end
end
