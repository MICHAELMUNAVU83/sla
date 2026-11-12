defmodule SlaWeb.ClientLive.FormComponent do
  @moduledoc "Client create/edit form, rendered inside a modal on the client list and client pages."
  use SlaWeb, :live_component
  alias Sla.Clients
  alias Sla.Clients.Client

  @impl true
  def update(%{client: client} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> to_form(Clients.change_client(client)) end)}
  end

  @impl true
  def handle_event("validate", %{"client" => attrs}, socket) do
    changeset = Clients.change_client(socket.assigns.client, attrs)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"client" => attrs}, socket) do
    result =
      if socket.assigns.client.id,
        do: Clients.update_client(socket.assigns.client, attrs),
        else: Clients.create_client(attrs)

    case result do
      {:ok, client} ->
        {:noreply,
         socket |> put_flash(:info, "Client saved.") |> push_navigate(to: ~p"/clients/#{client}")}

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
        id="client-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="modal-form"
      >
        <div class="form-grid">
          <.input
            field={@form[:type]}
            type="select"
            label="Client type"
            options={[{"Individual", "individual"}, {"Company", "company"}]}
            prompt="Select type"
          /><.input field={@form[:name]} label="Full / registered name" />
        </div>
        <div class="form-grid">
          <.input field={@form[:kra_pin]} label="KRA PIN" /><.input
            field={@form[:identification_number]}
            label="ID / registration number"
          />
        </div>
        <div class="form-grid">
          <.input field={@form[:email]} type="email" label="Email" /><.input
            field={@form[:phone]}
            type="tel"
            label="Phone"
          />
        </div>
        <.input field={@form[:address]} type="textarea" label="Address" />
        <.input
          field={@form[:kyc_status]}
          type="select"
          label="KYC status"
          options={
            Enum.map(
              Client.kyc_statuses(),
              &{String.replace(&1, "_", " ") |> String.capitalize(), &1}
            )
          }
        />
        <div class="form-actions">
          <.link patch={@return_to} class="btn-secondary">Cancel</.link>
          <.button id="save-client" class="btn-primary" phx-disable-with="Saving…">Save client</.button>
        </div>
      </.form>
    </div>
    """
  end
end
