defmodule SlaWeb.DiaryLive.Index do
  use SlaWeb, :live_view
  alias Sla.{Accounts, Tracker}

  def mount(_params, _session, socket) do
    if connected?(socket), do: Tracker.subscribe()
    user = socket.assigns.current_scope.user

    socket =
      assign(socket,
        users: Accounts.list_users(),
        partner?: user.role in ["partner", "admin"],
        selected_assignee: Integer.to_string(user.id)
      )

    {:ok, load_diary(socket)}
  end

  def handle_event("filter", %{"assignee" => id}, %{assigns: %{partner?: true}} = socket),
    do: {:noreply, socket |> assign(:selected_assignee, id) |> load_diary()}

  def handle_event("filter", _params, socket), do: {:noreply, socket}

  def handle_event("complete", %{"bring_up_id" => id, "note" => note}, socket) do
    {:ok, _} =
      Tracker.complete_bring_up(
        Tracker.get_bring_up!(id),
        socket.assigns.current_scope.user,
        note
      )

    {:noreply,
     socket |> load_diary() |> put_flash(:info, "Bring-up completed and activity logged.")}
  end

  def handle_event("snooze", %{"id" => id}, socket) do
    {:ok, _} = Tracker.snooze_bring_up(Tracker.get_bring_up!(id), Date.add(Date.utc_today(), 7))
    {:noreply, load_diary(socket)}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    {:ok, _} = Tracker.cancel_bring_up(Tracker.get_bring_up!(id))
    {:noreply, load_diary(socket)}
  end

  def handle_event("reassign", %{"bring_up_id" => id, "assignee_id" => assignee_id}, socket) do
    {:ok, _} = Tracker.reassign_bring_up(Tracker.get_bring_up!(id), assignee_id)
    {:noreply, load_diary(socket)}
  end

  def handle_info({:bring_up_changed, _}, socket), do: {:noreply, load_diary(socket)}
  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="My Diary" eyebrow="Bring-ups and deadlines" />
      <form :if={@partner?} id="diary-filter" phx-change="filter" class="diary-filter">
        <label>Viewing diary for</label><select name="assignee" class="select">{Phoenix.HTML.Form.options_for_select(
          Enum.map(@users, &{&1.name || &1.email, &1.id}),
          @selected_assignee
        )}</select>
      </form>
      <div class="diary-grid">
        <.diary_section title="Overdue" tone="overdue" stream={@streams.overdue} users={@users} /><.diary_section
          title="Today"
          tone="today"
          stream={@streams.today}
          users={@users}
        /><.diary_section title="Upcoming" tone="upcoming" stream={@streams.upcoming} users={@users} />
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :tone, :string, required: true
  attr :stream, :any, required: true
  attr :users, :list, required: true

  def diary_section(assigns) do
    ~H"""
    <section class="diary-section">
      <header>
        <span class={["diary-tone", "diary-tone-#{@tone}"]}></span><h2>{@title}</h2>
      </header><div id={"diary-#{@tone}"} phx-update="stream" class="diary-list">
        <div id={"diary-#{@tone}-empty"} class="empty-state hidden only:block">Nothing here.</div><article
          :for={{id, item} <- @stream}
          id={id}
          class="diary-card"
        >
          <div>
            <.link navigate={~p"/matters/#{item.matter}"}>{item.matter.file_number}</.link><time>{Calendar.strftime(
              item.due_on,
              "%d %b %Y"
            )}</time>
          </div><p>{item.note}</p><form
            id={"complete-#{item.id}"}
            phx-submit="complete"
            class="diary-complete"
          >
            <input type="hidden" name="bring_up_id" value={item.id} /><input
              name="note"
              class="input"
              value={"Completed: #{item.note}"}
              aria-label="Completion activity note"
            /><button class="mini-action complete">Complete</button>
          </form><div class="diary-actions">
            <button phx-click="snooze" phx-value-id={item.id} class="mini-action">Snooze 7d</button><form
              id={"reassign-#{item.id}"}
              phx-change="reassign"
            >
              <input type="hidden" name="bring_up_id" value={item.id} /><select
                name="assignee_id"
                class="small-select"
              >{Phoenix.HTML.Form.options_for_select(
                Enum.map(@users, &{&1.name || &1.email, &1.id}),
                item.assignee_id
              )}</select>
            </form><button phx-click="cancel" phx-value-id={item.id} class="mini-action danger">Cancel</button>
          </div>
        </article>
      </div>
    </section>
    """
  end

  defp load_diary(socket) do
    user_id = socket.assigns.current_scope.user.id

    diary =
      Tracker.diary(user_id, %{"assignee" => String.to_integer(socket.assigns.selected_assignee)})

    socket
    |> stream(:overdue, diary.overdue, reset: true)
    |> stream(:today, diary.today, reset: true)
    |> stream(:upcoming, diary.upcoming, reset: true)
  end
end
