defmodule SlaWeb.ClientLive.Index do
  use SlaWeb, :live_view
  alias Sla.Clients

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:filters, %{"search" => "", "type" => ""})
     |> stream(:clients, Clients.list_clients())}
  end

  def handle_params(_params, _url, socket), do: {:noreply, socket}

  def handle_event("filter", params, socket) do
    filters = Map.take(params, ["search", "type"])

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> stream(:clients, Clients.list_clients(filters), reset: true)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Clients" eyebrow="Relationship management">
        <:actions>
          <.link id="new-client" patch={~p"/clients/new"} class="btn-primary"><.icon
            name="hero-plus"
            class="size-4"
          /> New client</.link>
        </:actions>
      </.page_header>
      <.form for={to_form(@filters)} id="client-filters" phx-change="filter" class="filter-bar">
        <.input
          field={to_form(@filters)["search"]}
          type="search"
          placeholder="Search name, email or KRA PIN"
          phx-debounce="300"
        />
        <.input
          field={to_form(@filters)["type"]}
          type="select"
          options={[{"All client types", ""}, {"Individual", "individual"}, {"Company", "company"}]}
        />
      </.form>
      <div id="clients" phx-update="stream" class="data-list">
        <div id="clients-empty" class="empty-state hidden only:block">
          <.icon name="hero-user-group" class="size-10" /><p>No clients match this view.</p>
        </div>
        <.link
          :for={{id, client} <- @streams.clients}
          id={id}
          navigate={~p"/clients/#{client}"}
          class="data-row"
        >
          <div class="avatar-mark">{client.name |> String.first() |> String.upcase()}</div>
          <div class="min-w-0 flex-1">
            <p class="row-title">{client.name}</p><p class="row-meta">
              {client.email || "No email"} · {client.kra_pin || "KRA PIN pending"}
            </p>
          </div>
          <span class="status-pill">{String.capitalize(client.type)}</span><.icon
            name="hero-chevron-right"
            class="size-4 text-slate-400"
          />
        </.link>
      </div>
      <.modal
        :if={@live_action == :new}
        id="client-modal"
        title="New client"
        subtitle="Create the client record before opening matters"
        size="lg"
        show
        on_cancel={JS.patch(~p"/clients")}
      >
        <.live_component
          module={SlaWeb.ClientLive.FormComponent}
          id="new-client-form"
          client={%Sla.Clients.Client{}}
          return_to={~p"/clients"}
        />
      </.modal>
    </Layouts.app>
    """
  end
end
