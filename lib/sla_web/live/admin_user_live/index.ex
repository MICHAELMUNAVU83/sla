defmodule SlaWeb.AdminUserLive.Index do
  use SlaWeb, :live_view
  alias Sla.Accounts
  alias Sla.Accounts.User
  alias Sla.Policy

  def mount(_params, _session, socket) do
    if Policy.admin?(socket.assigns.current_scope) do
      {:ok,
       socket
       |> assign(form: invite_form(), roles: User.roles())
       |> stream(:users, Accounts.list_users())}
    else
      {:ok,
       socket
       |> put_flash(:error, "You are not authorized to manage users.")
       |> push_navigate(to: ~p"/matters")}
    end
  end

  def handle_event("invite", %{"invite" => attrs}, socket) do
    case Accounts.invite_user(attrs, &url(~p"/users/log-in/#{&1}")) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(form: invite_form())
         |> stream_insert(:users, user)
         |> close_modal("invite-modal")
         |> put_flash(:info, "Invitation sent to #{user.email}.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :invite))}
    end
  end

  def handle_event("update-user", %{"user_id" => id, "role" => role} = params, socket) do
    user = Accounts.get_user!(id)

    {:ok, user} =
      Accounts.update_user_admin(user, %{
        role: role,
        active: params["active"] == "true",
        name: user.name
      })

    {:noreply, socket |> stream_insert(:users, user) |> put_flash(:info, "User access updated.")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Team access" eyebrow="Administration">
        <:actions>
          <button
            id="open-invite"
            type="button"
            phx-click={show_modal("invite-modal")}
            class="btn-primary"
          ><.icon name="hero-user-plus" class="size-4" /> Invite team member</button>
        </:actions>
      </.page_header>
      <.modal
        id="invite-modal"
        title="Invite a team member"
        subtitle="They'll receive a secure sign-in link by email"
      >
        <.form for={@form} id="invite-user-form" phx-submit="invite" class="modal-form">
          <.input field={@form[:name]} label="Name" />
          <.input field={@form[:email]} type="email" label="Work email" />
          <.input
            field={@form[:role]}
            type="select"
            label="Role"
            options={Enum.map(@roles, &{String.capitalize(&1), &1})}
          />
          <div class="form-actions">
            <button type="button" class="btn-secondary" phx-click={hide_modal("invite-modal")}>Cancel</button>
            <.button id="invite-user" class="btn-primary" phx-disable-with="Sending…">Send secure invitation</.button>
          </div>
        </.form>
      </.modal>
      <div id="admin-users" phx-update="stream" class="data-list">
        <div :for={{id, user} <- @streams.users} id={id} class="data-row">
          <div class="avatar-mark">{user.email |> String.first() |> String.upcase()}</div><div class="flex-1">
            <p class="row-title">{user.name || user.email}</p><p class="row-meta">
              {user.email} · {String.capitalize(user.role)} access
            </p>
          </div><form
            id={"user-access-#{user.id}"}
            phx-change="update-user"
            class="flex items-center gap-3"
          >
            <input type="hidden" name="user_id" value={user.id} /><select
              name="role"
              class="small-select"
            >{Phoenix.HTML.Form.options_for_select(
              Enum.map(@roles, &{String.capitalize(&1), &1}),
              user.role
            )}</select><label class="toggle-label"><input
              type="checkbox"
              name="active"
              value="true"
              checked={user.active}
            /><span>Active</span></label>
          </form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp invite_form,
    do: to_form(%{"name" => "", "email" => "", "role" => "associate"}, as: :invite)
end
