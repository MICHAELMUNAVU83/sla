defmodule SlaWeb.ClientLive.Form do
  use SlaWeb, :live_view
  alias Sla.Clients
  alias Sla.Clients.Client

  def mount(params, _session, socket) do
    client = if params["id"], do: Clients.get_client!(params["id"]), else: %Client{}

    {:ok,
     assign(socket,
       client: client,
       form: to_form(Clients.change_client(client)),
       page_title: if(client.id, do: "Edit client", else: "New client")
     )}
  end

  def handle_event("validate", %{"client" => attrs}, socket),
    do:
      {:noreply,
       assign(
         socket,
         :form,
         to_form(Clients.change_client(socket.assigns.client, attrs), action: :validate)
       )}

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

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title={@page_title} eyebrow="Client record" />
      <.form for={@form} id="client-form" phx-change="validate" phx-submit="save" class="form-card">
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
          <.link
            navigate={if(@client.id, do: ~p"/clients/#{@client}", else: ~p"/clients")}
            class="btn-secondary"
          >Cancel</.link><.button id="save-client" class="btn-primary" phx-disable-with="Saving…">Save client</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end
end
