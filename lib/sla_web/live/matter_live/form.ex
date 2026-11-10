defmodule SlaWeb.MatterLive.Form do
  use SlaWeb, :live_view
  alias Sla.{Accounts, Clients, Matters}
  alias Sla.Matters.Matter

  def mount(params, _session, socket) do
    matter =
      if params["id"],
        do: Matters.get_matter_for_user!(params["id"], socket.assigns.current_scope.user),
        else: %Matter{client_id: parse_id(params["client_id"]), opened_on: Date.utc_today()}

    {:ok,
     assign(socket,
       matter: matter,
       form: to_form(Matters.change_matter(matter)),
       clients: Clients.list_clients(),
       users: Accounts.list_users(),
       page_title: if(matter.id, do: "Edit matter", else: "Open a matter")
     )}
  end

  def handle_event("validate", %{"matter" => attrs}, socket),
    do:
      {:noreply,
       assign(
         socket,
         :form,
         to_form(Matters.change_matter(socket.assigns.matter, attrs), action: :validate)
       )}

  def handle_event("save", %{"matter" => attrs}, socket) do
    result =
      if socket.assigns.matter.id,
        do: Matters.update_matter(socket.assigns.matter, attrs),
        else: Matters.create_matter(socket.assigns.current_scope, attrs)

    case result do
      {:ok, matter} ->
        {:noreply,
         socket
         |> put_flash(:info, "Matter saved as #{matter.file_number}.")
         |> push_navigate(to: ~p"/matters/#{matter}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title={@page_title} eyebrow="Matter file" />
      <.form for={@form} id="matter-form" phx-change="validate" phx-submit="save" class="form-card">
        <div class="form-grid">
          <.input
            field={@form[:client_id]}
            type="select"
            label="Client"
            options={Enum.map(@clients, &{&1.name, &1.id})}
            prompt="Select client"
          /><.input field={@form[:title]} label="Matter title" />
        </div>
        <div class="form-grid">
          <.input
            field={@form[:practice_area]}
            type="select"
            label="Practice area"
            options={Enum.map(Matter.practice_areas(), &{humanize(&1), &1})}
            prompt="Select area"
          /><.input
            field={@form[:status]}
            type="select"
            label="Status"
            options={Enum.map(Matter.statuses(), &{String.capitalize(&1), &1})}
          />
        </div>
        <div class="form-grid">
          <.input
            field={@form[:responsible_advocate_id]}
            type="select"
            label="Responsible advocate"
            options={Enum.map(@users, &{&1.name || &1.email, &1.id})}
            prompt="Unassigned"
          /><.input field={@form[:opened_on]} type="date" label="Opened on" />
        </div>
        <div class="form-grid">
          <.input field={@form[:court]} label="Court" /><.input
            field={@form[:case_number]}
            label="Case number"
          />
        </div>
        <.input :if={@matter.id} field={@form[:closed_on]} type="date" label="Closed on" />
        <div class="form-actions">
          <.link
            navigate={if(@matter.id, do: ~p"/matters/#{@matter}", else: ~p"/matters")}
            class="btn-secondary"
          >Cancel</.link><.button id="save-matter" class="btn-primary" phx-disable-with="Saving…">Save matter</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  defp parse_id(nil), do: nil
  defp parse_id(id), do: String.to_integer(id)

  defp humanize(value),
    do:
      value
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
end
