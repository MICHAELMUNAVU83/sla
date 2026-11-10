defmodule SlaWeb.UserLive.TwoFactor do
  use SlaWeb, :live_view
  alias Sla.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    secret = user.totp_secret || NimbleTOTP.secret()

    uri =
      NimbleTOTP.otpauth_uri("SLA Practice ERP:#{user.email}", secret,
        issuer: "Sichangi Law Alliance"
      )

    {:ok,
     assign(socket, secret: secret, uri: uri, form: to_form(%{"code" => ""}, as: :two_factor))}
  end

  def handle_event("enable", %{"two_factor" => %{"code" => code}}, socket) do
    case Accounts.enable_totp(socket.assigns.current_scope.user, socket.assigns.secret, code) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Two-factor authentication is now enabled.")
         |> push_navigate(to: ~p"/matters")}

      {:error, :invalid_code} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That code is invalid. Check your authenticator and try again."
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-xl">
        <.page_header title="Secure your account" eyebrow="Required setup" /><div class="form-card">
          <div class="security-mark"><.icon name="hero-shield-check" class="size-8" /></div><p class="text-slate-600">
            Add this account to your authenticator app using the setup key below, then enter the six-digit code. This is required for every SLA user.
          </p><div class="secret-box">
            <span>Setup key</span><code id="totp-secret">{Base.encode32(@secret, padding: false)}</code>
          </div><p class="break-all text-xs text-slate-400">{@uri}</p><.form
            for={@form}
            id="two-factor-form"
            phx-submit="enable"
          >
            <.input
              field={@form[:code]}
              type="text"
              inputmode="numeric"
              label="Six-digit authenticator code"
              autocomplete="one-time-code"
              required
            /><.button id="enable-two-factor" class="btn-primary w-full">Enable two-factor authentication</.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
