defmodule SlaWeb.MatterLive.FormComponent do
  @moduledoc "Matter open/edit form, rendered inside a modal on the matter list and matter pages."
  use SlaWeb, :live_component
  alias Sla.{Accounts, Clients, Matters}
  alias Sla.Matters.Matter

  @impl true
  def update(%{matter: matter} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:clients, fn -> Clients.list_clients() end)
     |> assign_new(:users, fn -> Accounts.list_users() end)
     |> assign_new(:form, fn -> to_form(Matters.change_matter(matter)) end)}
  end

  @impl true
  def handle_event("validate", %{"matter" => attrs}, socket) do
    changeset = Matters.change_matter(socket.assigns.matter, attrs)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="matter-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="modal-form"
      >
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
          <.link patch={@return_to} class="btn-secondary">Cancel</.link>
          <.button id="save-matter" class="btn-primary" phx-disable-with="Saving…">Save matter</.button>
        </div>
      </.form>
    </div>
    """
  end

  defp humanize(value),
    do:
      value
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
end
