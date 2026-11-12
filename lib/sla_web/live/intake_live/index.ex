defmodule SlaWeb.IntakeLive.Index do
  use SlaWeb, :live_view
  alias Sla.Practice

  def mount(_params, _session, socket),
    do:
      {:ok,
       assign(socket,
         intakes: Practice.list_intakes(),
         form: to_form(Practice.change_intake(), as: :intake),
         conflict_form: to_form(%{"search_terms" => "", "notes" => ""}, as: :conflict),
         conflict_result: nil
       )}

  def handle_event("save", %{"intake" => attrs}, socket) do
    case Practice.create_intake(socket.assigns.current_scope.user, attrs) do
      {:ok, _} ->
        {:noreply,
         assign(socket,
           intakes: Practice.list_intakes(),
           form: to_form(Practice.change_intake(), as: :intake)
         )
         |> close_modal("intake-modal")
         |> put_flash(:info, "Intake submitted for conflict and KYC review.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :intake))}
    end
  end

  def handle_event("conflict-check", %{"conflict" => attrs}, socket) do
    {:ok, check} = Practice.record_conflict_check(socket.assigns.current_scope.user, attrs)
    {:noreply, assign(socket, conflict_result: check)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Client intake & compliance" eyebrow="Practice management">
        <:actions>
          <button
            id="new-intake"
            type="button"
            phx-click={show_modal("intake-modal")}
            class="btn-primary"
          ><.icon name="hero-plus" class="size-4" /> New client intake</button>
        </:actions>
      </.page_header>
      <div class="grid gap-6 xl:grid-cols-2">
        <.form
          for={@conflict_form}
          id="conflict-check-form"
          phx-submit="conflict-check"
          class="form-card"
        >
          <h2 class="text-lg font-bold">Conflict search</h2><p class="text-sm text-slate-500">
            Searches clients, opposing parties, and opposing counsel.
          </p>
          <.input field={@conflict_form[:search_terms]} label="Names (comma-separated)" />
          <.input field={@conflict_form[:notes]} type="textarea" label="Review notes" />
          <.button id="run-conflict-check" class="btn-secondary">Run and store check</.button>
          <div
            :if={@conflict_result}
            id="conflict-check-result"
            class={[
              "mt-4 rounded-xl p-4 text-sm font-semibold",
              @conflict_result.result == "clear" && "bg-emerald-50 text-emerald-800",
              @conflict_result.result != "clear" && "bg-amber-50 text-amber-800"
            ]}
          >
            Result: {String.replace(@conflict_result.result, "_", " ")}
          </div>
        </.form>
        <section id="intake-queue" class="content-card">
          <h2 class="text-lg font-bold">Intake queue</h2><div class="mt-4 space-y-3">
            <p :if={@intakes == []} class="empty-copy">No submitted intakes.</p><article
              :for={intake <- @intakes}
              id={"intake-#{intake.id}"}
              class="detail-card"
            >
              <span>{intake.client_type} · {intake.status}</span><strong>{intake.name}</strong>
            </article>
          </div>
        </section>
      </div>
      <.modal
        id="intake-modal"
        title="New client intake"
        subtitle="Submitted for conflict and KYC review"
        size="lg"
      >
        <.form for={@form} id="client-intake-form" phx-submit="save" class="modal-form">
          <div class="form-grid">
            <.input
              field={@form[:client_type]}
              type="select"
              label="Client type"
              options={[{"Individual", "individual"}, {"Company", "company"}]}
            /><.input field={@form[:name]} label="Full name / company" />
          </div>
          <div class="form-grid">
            <.input field={@form[:email]} type="email" label="Email" /><.input
              field={@form[:phone]}
              label="Phone"
            />
          </div>
          <div class="form-grid">
            <.input field={@form[:identification_number]} label="ID / registration no." /><.input
              field={@form[:kra_pin]}
              label="KRA PIN"
            />
          </div>
          <.input field={@form[:address]} type="textarea" label="Address" />
          <.input
            field={@form[:matter_summary]}
            type="textarea"
            label="Proposed instructions and all known parties"
          />
          <.input
            field={@form[:consent_given]}
            type="checkbox"
            label="Client consent to collect and process this information has been recorded"
          />
          <div class="form-actions">
            <button type="button" class="btn-secondary" phx-click={hide_modal("intake-modal")}>Cancel</button>
            <.button id="submit-client-intake" class="btn-primary" phx-disable-with="Submitting…">Submit intake</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end
end
