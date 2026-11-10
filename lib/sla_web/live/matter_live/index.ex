defmodule SlaWeb.MatterLive.Index do
  use SlaWeb, :live_view
  alias Sla.{Accounts, Clients, Matters}
  alias Sla.Matters.Matter

  def mount(_params, _session, socket) do
    filters = %{
      "search" => "",
      "status" => "",
      "practice_area" => "",
      "advocate" => "",
      "client" => ""
    }

    {:ok,
     socket
     |> assign(filters: filters, users: Accounts.list_users(), clients: Clients.list_clients())
     |> stream(:matters, Matters.list_matters_for_user(socket.assigns.current_scope.user))}
  end

  def handle_event("filter", params, socket) do
    filters = Map.take(params, ~w(search status practice_area advocate client))

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> stream(
       :matters,
       Matters.list_matters_for_user(socket.assigns.current_scope.user, filters),
       reset: true
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Matters" eyebrow="File register">
        <:actions>
          <.link id="new-matter" navigate={~p"/matters/new"} class="btn-primary"><.icon
            name="hero-folder-plus"
            class="size-4"
          /> New matter</.link>
        </:actions>
      </.page_header>
      <.form
        for={to_form(@filters)}
        id="matter-filters"
        phx-change="filter"
        class="filter-bar filter-bar-wide"
      >
        <.input
          field={to_form(@filters)["search"]}
          type="search"
          placeholder="Search file, title or client"
          phx-debounce="300"
        />
        <.input
          field={to_form(@filters)["status"]}
          type="select"
          options={[{"All statuses", ""} | Enum.map(Matter.statuses(), &{String.capitalize(&1), &1})]}
        />
        <.input
          field={to_form(@filters)["practice_area"]}
          type="select"
          options={[
            {"All practice areas", ""} | Enum.map(Matter.practice_areas(), &{humanize(&1), &1})
          ]}
        />
        <.input
          field={to_form(@filters)["advocate"]}
          type="select"
          options={[{"All advocates", ""} | Enum.map(@users, &{&1.name || &1.email, &1.id})]}
        />
        <.input
          field={to_form(@filters)["client"]}
          type="select"
          options={[{"All clients", ""} | Enum.map(@clients, &{&1.name, &1.id})]}
        />
      </.form>
      <div id="matters" phx-update="stream" class="data-list">
        <div class="empty-state hidden only:block">
          <.icon name="hero-folder-open" class="size-10" /><p>No matters match these filters.</p>
        </div>
        <.link
          :for={{id, matter} <- @streams.matters}
          id={id}
          navigate={~p"/matters/#{matter}"}
          class="data-row"
        >
          <div class="file-mark"><.icon name="hero-scale" class="size-5" /></div><div class="min-w-0 flex-1">
            <p class="row-title">{matter.title}</p><p class="row-meta">
              {matter.file_number} · {matter.client.name}
            </p>
          </div><div class="hidden text-right md:block">
            <p class="row-title text-sm">{humanize(matter.practice_area)}</p><p class="row-meta">
              {(matter.responsible_advocate && matter.responsible_advocate.name) || "Unassigned"}
            </p>
          </div><span class="status-pill">{matter.status}</span>
          <p class="latest-list-action">{matter.last_activity_summary || "No activity yet"}</p>
        </.link>
      </div>
    </Layouts.app>
    """
  end

  defp humanize(value),
    do:
      value
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
end
