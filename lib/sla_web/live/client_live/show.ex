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

  def handle_event("tab", %{"tab" => tab}, socket), do: {:noreply, assign(socket, :tab, tab)}

  def handle_event("save-kyc", %{"kyc" => attrs}, socket) do
    case Practice.upsert_kyc(socket.assigns.client, socket.assigns.current_scope.user, attrs) do
      {:ok, check} ->
        {:noreply,
         assign(socket, kyc_form: to_form(Sla.Practice.KycCheck.changeset(check, %{}), as: :kyc))
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
          <.link id="edit-client" navigate={~p"/clients/#{@client}/edit"} class="btn-secondary"><.icon
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
              <.form for={@kyc_form} id="client-kyc-form" phx-submit="save-kyc" class="activity-form">
                <h2 class="text-lg font-bold">KYC / AML review</h2>
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
                <.button id="save-client-kyc" class="btn-primary">Save review</.button>
              </.form>
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
    </Layouts.app>
    """
  end
end
