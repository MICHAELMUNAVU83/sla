defmodule SlaWeb.AllocationLive.Index do
  use SlaWeb, :live_view
  alias Sla.{Accounts, Allocation}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(users: Accounts.list_users(), page_title: "Work allocation")
     |> assign(reassign_form: reassign_form())
     |> load()}
  end

  def handle_event("reassign", %{"reassign" => %{"matter_id" => ""}}, socket),
    do: {:noreply, put_flash(socket, :error, "Choose a matter to reassign.")}

  def handle_event(
        "reassign",
        %{"reassign" => %{"matter_id" => id, "advocate_id" => advocate}},
        socket
      ) do
    case Allocation.reassign_matter(socket.assigns.current_scope.user, id, advocate) do
      {:ok, matter} ->
        {:noreply,
         socket
         |> load()
         |> assign(reassign_form: reassign_form())
         |> close_modal("reassign-modal")
         |> put_flash(:info, "#{matter.file_number} reassigned.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reassign the matter.")}
    end
  end

  def handle_event("prefill", %{"matter" => id}, socket),
    do: {:noreply, assign(socket, reassign_form: reassign_form(id))}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Work allocation" eyebrow="Who handles what">
        <:actions>
          <button
            id="open-reassign"
            type="button"
            phx-click={JS.push("prefill", value: %{matter: ""}) |> show_modal("reassign-modal")}
            class="btn-primary"
          ><.icon name="hero-arrows-right-left" class="size-4" /> Reassign a matter</button>
        </:actions>
      </.page_header>

      <div id="allocation-summary" class="detail-grid">
        <div class="detail-card">
          <span>Open matters</span><strong>{length(@workload.matters)}</strong>
        </div>
        <div class="detail-card">
          <span>Team members</span><strong>{length(@workload.members)}</strong>
        </div>
        <div class="detail-card">
          <span>Unassigned matters</span><strong>{length(@workload.unassigned)}</strong>
        </div>
      </div>

      <section :if={@workload.unassigned != []} id="unassigned-matters" class="content-card mb-6">
        <h2 class="section-title">Needs an advocate</h2>
        <div class="mt-3 space-y-2">
          <div
            :for={matter <- @workload.unassigned}
            id={"unassigned-#{matter.id}"}
            class="allocation-row"
          >
            <.link navigate={~p"/matters/#{matter}"}>
              <strong>{matter.title}</strong><span>{matter.file_number}</span>
            </.link>
            <button
              type="button"
              class="mini-action"
              phx-click={
                JS.push("prefill", value: %{matter: matter.id}) |> show_modal("reassign-modal")
              }
            >Assign</button>
          </div>
        </div>
      </section>

      <div id="team-workload" class="allocation-grid">
        <article :for={m <- @workload.members} id={"member-#{m.user.id}"} class="allocation-card">
          <header>
            <div class="avatar-mark">{initial(m.user)}</div>
            <div class="min-w-0 flex-1">
              <h3>{display_name(m.user)}</h3>
              <p>{String.capitalize(m.user.role)}</p>
            </div>
            <span :if={m.overdue > 0} class="allocation-overdue">{m.overdue} overdue</span>
          </header>
          <div class="allocation-stats">
            <div><b>{length(m.matters)}</b><span>Matters</span></div>
            <div><b>{length(m.tasks)}</b><span>Open tasks</span></div>
            <div><b>{length(m.bring_ups)}</b><span>Bring-ups</span></div>
            <div><b>{length(m.events)}</b><span>Upcoming</span></div>
          </div>
          <div class="allocation-section">
            <h4>Matters</h4>
            <p :if={m.matters == []} class="allocation-empty">No matters assigned.</p>
            <div :for={matter <- m.matters} class="allocation-row">
              <.link navigate={~p"/matters/#{matter}"}>
                <strong>{matter.title}</strong><span>{matter.file_number}</span>
              </.link>
              <button
                type="button"
                class="mini-action"
                phx-click={
                  JS.push("prefill", value: %{matter: matter.id}) |> show_modal("reassign-modal")
                }
              >Reassign</button>
            </div>
          </div>
          <div :if={m.tasks != [] or m.bring_ups != []} class="allocation-section">
            <h4>Next up</h4>
            <div :for={task <- Enum.take(m.tasks, 3)} class="allocation-row">
              <span class="allocation-item">
                <strong>{task.title}</strong><span>Task · {task.matter.file_number} · {due(
                  task.due_on
                )}</span>
              </span>
            </div>
            <div :for={b <- Enum.take(m.bring_ups, 3)} class="allocation-row">
              <span class="allocation-item">
                <strong>{b.note}</strong><span>Bring-up · {b.matter.file_number} · {due(b.due_on)}</span>
              </span>
            </div>
          </div>
        </article>
      </div>

      <.modal
        id="reassign-modal"
        title="Reassign a matter"
        subtitle="Change who is responsible for a file"
      >
        <.form for={@reassign_form} id="reassign-form" phx-submit="reassign" class="modal-form">
          <.input
            field={@reassign_form[:matter_id]}
            type="select"
            label="Matter"
            prompt="Select a matter"
            options={Enum.map(@workload.matters, &{"#{&1.file_number} — #{&1.title}", &1.id})}
          />
          <.input
            field={@reassign_form[:advocate_id]}
            type="select"
            label="Responsible advocate"
            prompt="Unassigned"
            options={Enum.map(@users, &{&1.name || &1.email, &1.id})}
          />
          <div class="form-actions">
            <button type="button" class="btn-secondary" phx-click={hide_modal("reassign-modal")}>Cancel</button>
            <.button id="save-reassign" class="btn-primary" phx-disable-with="Saving…">Reassign</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  defp load(socket),
    do: assign(socket, :workload, Allocation.workload(socket.assigns.current_scope.user))

  defp reassign_form(matter_id \\ ""),
    do: to_form(%{"matter_id" => matter_id, "advocate_id" => ""}, as: :reassign)

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(user), do: user.email

  defp initial(user), do: user |> display_name() |> String.first() |> String.upcase()

  defp due(nil), do: "no due date"
  defp due(date), do: Calendar.strftime(date, "%d %b")
end
