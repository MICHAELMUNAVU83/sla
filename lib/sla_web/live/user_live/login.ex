defmodule SlaWeb.UserLive.Login do
  use SlaWeb, :live_view

  alias Sla.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main id="staff-login" class="auth-shell">
        <section class="auth-story" aria-label="Sichangi Law Alliance">
          <.link navigate={~p"/"} class="auth-brand"><img
            src={~p"/images/logo-sla-wordmark.png"}
            alt="Sichangi Law Alliance"
          /></.link>
          <div class="auth-story-copy">
            <p class="auth-kicker">Private practice workspace</p><h1>
              Clarity for every matter.<br />Context for every decision.
            </h1><p>
              Secure access to the people, documents, deadlines, and financial insight that move the practice forward.
            </p>
          </div>
          <p class="auth-story-foot">African legal excellence · Since 1998</p>
        </section>
        <section class="auth-panel">
          <div class="auth-card">
            <.link navigate={~p"/"} class="auth-back"><.icon name="hero-arrow-left" class="size-4" />
            Back to the SLA website</.link>
            <p class="auth-kicker">Staff access</p><h2>Log in</h2>
            <p class="auth-intro">
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Sign in to continue to the SLA practice workspace. New team member?
                <.link navigate={~p"/users/register"} class="auth-inline-link">Sign up</.link>
                for an account.
              <% end %>
            </p>

            <div :if={local_mail_adapter?()} class="alert alert-info auth-alert">
              <.icon name="hero-information-circle" class="size-6 shrink-0" />
              <div>
                <p>You are running the local mail adapter.</p>
                <p>
                  To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
                </p>
              </div>
            </div>

            <.form
              for={@form}
              id="login_form_magic"
              action={~p"/users/log-in"}
              phx-submit="submit_magic"
              class="auth-form"
            >
              <.input
                id="login_form_magic_email"
                readonly={!!@current_scope}
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                spellcheck="false"
                required
                phx-mounted={JS.focus()}
              />
              <.button class="auth-primary-button w-full">
                Log in with email link <.icon name="hero-arrow-right" class="size-4" />
              </.button>
            </.form>

            <div class="auth-divider"><span>or use your password</span></div>

            <.form
              for={@form}
              id="login_form_password"
              action={~p"/users/log-in"}
              phx-submit="submit_password"
              phx-trigger-action={@trigger_submit}
              class="auth-form"
            >
              <.input
                id="login_form_password_email"
                readonly={!!@current_scope}
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                spellcheck="false"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
                spellcheck="false"
              />
              <.button class="auth-primary-button w-full" name={@form[:remember_me].name} value="true">
                Sign in and stay signed in <.icon name="hero-arrow-right" class="size-4" />
              </.button>
              <.button class="auth-secondary-button w-full">
                Sign in for this session only
              </.button>
            </.form>
          </div>
        </section>
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, push_navigate(socket, to: ~p"/matters")}
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:sla, Sla.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
