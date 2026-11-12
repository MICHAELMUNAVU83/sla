defmodule SlaWeb.CalendarLive.Index do
  use SlaWeb, :live_view
  alias Sla.{Accounts, Matters, Practice}

  def mount(params, _session, socket) do
    date = parse_date(params["date"])

    {:ok,
     assign(socket,
       date: date,
       events: Practice.list_events(),
       cause_list: Practice.court_diary(date),
       matters: Matters.list_matters_for_user(socket.assigns.current_scope.user),
       users: Accounts.list_users(),
       form: to_form(Practice.change_event(), as: :event)
     )}
  end

  def handle_event("save", %{"event" => attrs}, socket) do
    case Practice.create_event(socket.assigns.current_scope.user, attrs) do
      {:ok, _} ->
        {:noreply,
         assign(socket,
           events: Practice.list_events(),
           cause_list: Practice.court_diary(socket.assigns.date),
           form: to_form(Practice.change_event(), as: :event)
         )
         |> close_modal("calendar-event-modal")
         |> put_flash(:info, "Calendar event added.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :event))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Court diary & calendar" eyebrow="Practice management">
        <:actions>
          <button
            id="new-calendar-event"
            type="button"
            phx-click={show_modal("calendar-event-modal")}
            class="btn-primary"
          ><.icon name="hero-plus" class="size-4" /> New diary event</button>
        </:actions>
      </.page_header>
      <div class="space-y-6">
        <section id="court-cause-list" class="content-card">
          <div class="tab-toolbar">
            <div>
              <p class="text-xs font-bold uppercase tracking-widest text-amber-700">
                Daily cause list
              </p><h2 class="text-xl font-bold">{Calendar.strftime(@date, "%A, %d %B %Y")}</h2>
            </div><.link
              patch={~p"/calendar?date=#{Date.to_iso8601(Date.add(@date, 1))}"}
              class="btn-secondary"
            >Next day</.link>
          </div>
          <div class="mt-5 space-y-3">
            <p :if={@cause_list == []} id="cause-list-empty" class="empty-copy">
              No hearings or mentions listed.
            </p>
            <article :for={event <- @cause_list} id={"cause-event-#{event.id}"} class="detail-card">
              <span>{Calendar.strftime(event.starts_at, "%H:%M")} · {event.court || event.location ||
                "Venue pending"}</span><strong>{event.title}</strong><small>{event.matter &&
                event.matter.file_number}</small>
            </article>
          </div>
        </section>
        <section id="firm-calendar" class="content-card">
          <h2 class="text-lg font-bold">Firm calendar</h2>
          <div class="mt-4 divide-y divide-slate-100">
            <article
              :for={event <- @events}
              id={"calendar-event-#{event.id}"}
              class="flex items-center gap-4 py-4"
            >
              <div class="rounded-xl bg-slate-900 px-3 py-2 text-center text-white">
                <b class="block text-lg">{event.starts_at.day}</b><small>{Calendar.strftime(
                  event.starts_at,
                  "%b"
                )}</small>
              </div><div>
                <strong>{event.title}</strong><p class="text-sm text-slate-500">
                  {humanize(event.event_type)} · {event.matter && event.matter.file_number}
                </p>
              </div>
            </article>
          </div>
        </section>
      </div>
      <.modal
        id="calendar-event-modal"
        title="New diary event"
        subtitle="Hearings, mentions, meetings and deadlines"
      >
        <.form for={@form} id="firm-calendar-form" phx-submit="save" class="modal-form">
          <.input field={@form[:title]} label="Title" />
          <.input
            field={@form[:event_type]}
            type="select"
            label="Type"
            options={Enum.map(Sla.Practice.CalendarEvent.types(), &{humanize(&1), &1})}
          />
          <.input
            field={@form[:matter_id]}
            type="select"
            label="Matter"
            options={Enum.map(@matters, &{"#{&1.file_number} — #{&1.title}", &1.id})}
            prompt="Firm-wide"
          />
          <.input
            field={@form[:assigned_to_id]}
            type="select"
            label="Assigned to"
            options={Enum.map(@users, &{&1.name || &1.email, &1.id})}
            prompt="Unassigned"
          />
          <.input field={@form[:starts_at]} type="datetime-local" label="Starts" />
          <.input field={@form[:ends_at]} type="datetime-local" label="Ends" />
          <.input field={@form[:court]} label="Court" />
          <.input field={@form[:location]} label="Location" />
          <.input field={@form[:notes]} type="textarea" label="Notes" />
          <div class="form-actions">
            <button type="button" class="btn-secondary" phx-click={hide_modal("calendar-event-modal")}>Cancel</button>
            <.button id="save-calendar-event" class="btn-primary" phx-disable-with="Saving…">Add to diary</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  defp parse_date(nil), do: Date.utc_today()

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp humanize(value), do: value |> String.replace("_", " ") |> String.capitalize()
end
