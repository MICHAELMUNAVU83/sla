defmodule SlaWeb.ClientLive.Show do
  use SlaWeb, :live_view
  alias Sla.{Clients, Documents, Practice}

  def mount(%{"id" => id}, _session, socket) do
    client = Clients.get_client!(id)

    {:ok,
     socket
     |> assign(
       client: client,
       tab: "matters",
       kyc_form: to_form(Practice.change_kyc(client.id), as: :kyc)
     )
     |> stream(
       :documents,
       Documents.list_documents(socket.assigns.current_scope.user, %{client_id: client.id})
     )}
  end

  def handle_params(_params, _url, socket), do: {:noreply, socket}

  # The documents stream only renders while its tab is visible, so re-send it on every tab switch.
  def handle_event("tab", %{"tab" => tab}, socket) do
    documents =
      Documents.list_documents(socket.assigns.current_scope.user, %{
        client_id: socket.assigns.client.id
      })

    {:noreply, socket |> assign(:tab, tab) |> stream(:documents, documents, reset: true)}
  end

  def handle_event("save-kyc", %{"kyc" => attrs}, socket) do
    case Practice.upsert_kyc(socket.assigns.client, socket.assigns.current_scope.user, attrs) do
      {:ok, check} ->
        {:noreply,
         assign(socket, kyc_form: to_form(Sla.Practice.KycCheck.changeset(check, %{}), as: :kyc))
         |> close_modal("kyc-modal")
         |> put_flash(:info, "KYC review saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, kyc_form: to_form(changeset, as: :kyc))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title={@client.name} eyebrow="Client overview">
        <:actions>
          <.link id="edit-client" patch={~p"/clients/#{@client}/edit"} class="btn-secondary"><.icon
            name="hero-pencil-square"
            class="size-4"
          /> Edit</.link><.link
            navigate={~p"/matters/new?client_id=#{@client.id}"}
            class="btn-primary"
          >Open matter</.link>
        </:actions>
      </.page_header>
      <div class="detail-grid">
        <div class="detail-card">
          <span>KRA PIN</span><strong>{@client.kra_pin || "Pending"}</strong>
        </div><div class="detail-card">
          <span>KYC status</span><strong>{String.capitalize(
            String.replace(@client.kyc_status, "_", " ")
          )}</strong>
        </div><div class="detail-card">
          <span>Contact</span><strong>{@client.email || @client.phone || "Not provided"}</strong>
        </div>
      </div>
      <nav id="client-tabs" class="tabs">
        <button
          :for={tab <- ~w(matters documents compliance financials activity)}
          id={"client-tab-#{tab}"}
          phx-click="tab"
          phx-value-tab={tab}
          class={["tab", @tab == tab && "tab-active"]}
        >{String.capitalize(tab)}</button>
      </nav>
      <section id={"client-#{@tab}-panel"} class="content-card">
        <%= cond do %>
          <% @tab == "matters" -> %>
            <div class="space-y-3">
              <.link
                :for={matter <- @client.matters}
                navigate={~p"/matters/#{matter}"}
                class="data-row"
              ><div class="flex-1">
                <p class="row-title">{matter.title}</p><p class="row-meta">{matter.file_number}</p>
              </div><span class="status-pill">{matter.status}</span></.link><p
                :if={@client.matters == []}
                class="empty-copy"
              >
                No matters opened yet.
              </p>
            </div>
          <% @tab == "documents" -> %>
            <div class="tab-toolbar">
              <p>General and matter files for this client.</p><.link
                navigate={~p"/documents?client_id=#{@client.id}"}
                class="btn-primary"
              >Open document workspace</.link>
            </div><div id="client-documents" phx-update="stream" class="document-grid">
              <div id="client-documents-empty" class="empty-state hidden only:block">
                No documents filed yet.
              </div><.link
                :for={{id, document} <- @streams.documents}
                id={id}
                navigate={~p"/documents/#{document}"}
                class="document-card"
              ><div class="document-icon"><.icon name="hero-document-text" class="size-6" /></div><div>
                <h3>{document.title}</h3><p>
                  {(document.matter && document.matter.file_number) || "General"}
                </p><span>{document.category.name}</span>
              </div></.link>
            </div>
          <% @tab == "compliance" -> %>
            <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_18rem]">
              <div id="client-kyc-summary">
                <div class="tab-toolbar">
                  <h2 class="text-lg font-bold">KYC / AML review</h2>
                  <button
                    id="edit-client-kyc"
                    type="button"
                    phx-click={show_modal("kyc-modal")}
                    class="btn-primary"
                  ><.icon name="hero-pencil-square" class="size-4" /> Update review</button>
                </div>
                <dl class="summary-list mt-4">
                  <div :for={{field, label} <- kyc_checks()}>
                    <dt>{label}</dt>
                    <dd>{if checked?(@kyc_form, field), do: "✓ Verified", else: "Pending"}</dd>
                  </div>
                  <div>
                    <dt>Risk rating</dt>
                    <dd>
                      {String.capitalize(
                        to_string(Phoenix.HTML.Form.input_value(@kyc_form, :risk_rating) || "unrated")
                      )}
                    </dd>
                  </div>
                </dl>
              </div>
              <aside class="detail-card h-fit">
                <span>Evidence</span><strong>File KYC documents securely</strong><p class="mt-2 text-sm text-slate-500">
                  Upload ID, KRA PIN, CR12, and beneficial ownership evidence in the KYC category.
                </p><.link
                  navigate={~p"/documents?client_id=#{@client.id}"}
                  class="btn-secondary mt-4"
                >Open documents</.link>
              </aside>
            </div>
          <% true -> %>
            <p class="empty-copy">This workspace is ready for the {@tab} milestone.</p>
        <% end %>
      </section>
      <.modal id="kyc-modal" title="KYC / AML review" subtitle={@client.name}>
        <.form for={@kyc_form} id="client-kyc-form" phx-submit="save-kyc" class="modal-form">
          <div class="grid gap-3 sm:grid-cols-2">
            <.input field={@kyc_form[:id_verified]} type="checkbox" label="ID verified" /><.input
              field={@kyc_form[:kra_pin_verified]}
              type="checkbox"
              label="KRA PIN verified"
            /><.input
              field={@kyc_form[:cr12_verified]}
              type="checkbox"
              label="CR12 verified (companies)"
            /><.input
              field={@kyc_form[:beneficial_owners_verified]}
              type="checkbox"
              label="Beneficial owners verified"
            /><.input
              field={@kyc_form[:source_of_funds_verified]}
              type="checkbox"
              label="Source of funds verified"
            />
          </div>
          <.input
            field={@kyc_form[:risk_rating]}
            type="select"
            label="Risk rating"
            options={[
              {"Unrated", "unrated"},
              {"Low", "low"},
              {"Medium", "medium"},
              {"High", "high"},
              {"Prohibited", "prohibited"}
            ]}
          />
          <.input field={@kyc_form[:notes]} type="textarea" label="Review notes" />
          <div class="form-actions">
            <button type="button" class="btn-secondary" phx-click={hide_modal("kyc-modal")}>Cancel</button>
            <.button id="save-client-kyc" class="btn-primary" phx-disable-with="Saving…">Save review</.button>
          </div>
        </.form>
      </.modal>
      <.modal
        :if={@live_action == :edit}
        id="client-modal"
        title="Edit client"
        subtitle={@client.name}
        size="lg"
        show
        on_cancel={JS.patch(~p"/clients/#{@client}")}
      >
        <.live_component
          module={SlaWeb.ClientLive.FormComponent}
          id={"edit-client-form-#{@client.id}"}
          client={@client}
          return_to={~p"/clients/#{@client}"}
        />
      </.modal>
    </Layouts.app>
    """
  end

  defp kyc_checks,
    do: [
      {:id_verified, "ID verified"},
      {:kra_pin_verified, "KRA PIN verified"},
      {:cr12_verified, "CR12 verified (companies)"},
      {:beneficial_owners_verified, "Beneficial owners verified"},
      {:source_of_funds_verified, "Source of funds verified"}
    ]

  defp checked?(form, field),
    do: Phoenix.HTML.Form.normalize_value("checkbox", Phoenix.HTML.Form.input_value(form, field))
end
