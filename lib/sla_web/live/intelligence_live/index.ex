defmodule SlaWeb.IntelligenceLive.Index do
  use SlaWeb, :live_view
  alias Sla.{AI, Matters}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    settings = AI.settings()

    {:ok,
     assign(socket,
       settings: settings,
       settings_form: to_form(AI.change_settings(), as: :settings),
       matters: Matters.list_matters_for_user(user, %{}),
       selected_matter: nil,
       outputs: AI.list_outputs(%{status: "pending_review"}),
       action_form:
         to_form(
           %{
             "matter_id" => "",
             "operation" => "matter_summary",
             "draft_type" => "follow-up email",
             "instructions" => ""
           },
           as: :assistant
         ),
       search_form: to_form(%{"query" => ""}, as: :search),
       search_results: []
     )}
  end

  def handle_event("save-settings", %{"settings" => attrs}, socket) do
    case AI.update_settings(socket.assigns.current_scope.user, attrs) do
      {:ok, settings} ->
        {:noreply,
         assign(socket,
           settings: settings,
           settings_form: to_form(AI.change_settings(), as: :settings)
         )
         |> put_flash(:info, "AI settings updated.")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Only partners and admins can change AI settings.")}

      {:error, changeset} ->
        {:noreply, assign(socket, settings_form: to_form(changeset, as: :settings))}
    end
  end

  def handle_event("generate", %{"assistant" => attrs}, socket) do
    user = socket.assigns.current_scope.user
    matter = Matters.get_matter_for_user!(attrs["matter_id"], user)

    result =
      case attrs["operation"] do
        "matter_summary" -> AI.generate_matter_summary(matter, user)
        "next_action" -> AI.suggest_next_action(matter, user)
        "draft" -> AI.draft(matter, user, attrs["draft_type"], attrs["instructions"])
        "time_suggestion" -> AI.suggest_time(matter, user)
        "collection_insight" -> AI.collections_insight(matter, user)
      end

    case result do
      {:ok, _} ->
        {:noreply, refresh(socket) |> put_flash(:info, "Suggestion generated for review.")}

      {:error, :disabled} ->
        {:noreply, put_flash(socket, :error, "AI is disabled for this firm.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "AI request failed: #{inspect(reason)}")}
    end
  end

  def handle_event("review", %{"id" => id, "decision" => decision}, socket) do
    output = Enum.find(socket.assigns.outputs, &(&1.id == String.to_integer(id)))

    result =
      if decision == "accept",
        do: AI.accept_output(output, socket.assigns.current_scope.user),
        else: AI.reject_output(output, socket.assigns.current_scope.user)

    case result do
      {:ok, _} ->
        {:noreply, refresh(socket) |> put_flash(:info, "Review recorded.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not apply suggestion: #{inspect(reason)}")}
    end
  end

  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply,
     assign(socket,
       search_results: AI.natural_language_search(socket.assigns.current_scope.user, query)
     )}
  end

  defp refresh(socket), do: assign(socket, outputs: AI.list_outputs(%{status: "pending_review"}))

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="AI workspace" eyebrow="Human-reviewed intelligence">
        <:actions>
          <span
            id="ai-status"
            class={[
              "rounded-full px-3 py-1 text-xs font-bold",
              @settings.enabled && "bg-emerald-100 text-emerald-800",
              !@settings.enabled && "bg-slate-100 text-slate-600"
            ]}
          >{if @settings.enabled, do: "Enabled", else: "Disabled"}</span>
        </:actions>
      </.page_header>
      <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <div class="space-y-6">
          <section class="content-card" id="ai-assistant-panel">
            <h2 class="text-lg font-bold text-slate-900">Matter assistant</h2>
            <p class="mt-1 text-sm text-slate-500">
              Every result is held for review. Nothing is sent, filed, or scheduled automatically.
            </p>
            <.form for={@action_form} id="ai-action-form" phx-submit="generate" class="mt-5 space-y-4">
              <div class="form-grid">
                <.input
                  field={@action_form[:matter_id]}
                  type="select"
                  label="Matter"
                  prompt="Select a matter"
                  options={Enum.map(@matters, &{"#{&1.file_number} · #{&1.title}", &1.id})}
                  required
                />
                <.input
                  field={@action_form[:operation]}
                  type="select"
                  label="Assistance"
                  options={[
                    {"Where are we?", "matter_summary"},
                    {"Suggest next action", "next_action"},
                    {"Draft correspondence", "draft"},
                    {"Suggest time entries", "time_suggestion"},
                    {"Collections insight", "collection_insight"}
                  ]}
                />
              </div>
              <div class="form-grid">
                <.input field={@action_form[:draft_type]} label="Draft type" />
                <.input field={@action_form[:instructions]} label="Instructions" />
              </div>
              <.button id="generate-ai-output" class="btn-primary"><.icon
                name="hero-sparkles"
                class="size-4"
              /> Generate for review</.button>
            </.form>
          </section>

          <section class="content-card" id="ai-review-queue">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-bold">Review queue</h2><span class="text-sm text-slate-500">{length(
                @outputs
              )} pending</span>
            </div>
            <div :if={@outputs == []} id="ai-review-empty" class="empty-state mt-5">
              No suggestions awaiting review.
            </div>
            <article
              :for={output <- @outputs}
              id={"ai-output-#{output.id}"}
              class="mt-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="text-xs font-bold uppercase tracking-wider text-amber-700">
                    {output.kind |> String.replace("_", " ") |> String.capitalize()}
                  </p>
                  <p class="mt-1 text-xs text-slate-500">
                    {output.matter && output.matter.file_number}
                  </p>
                </div>
                <span class="rounded-full bg-amber-50 px-2 py-1 text-xs text-amber-800">AI suggestion · verify</span>
              </div>
              <pre class="mt-4 whitespace-pre-wrap rounded-xl bg-slate-950 p-4 text-xs leading-6 text-slate-100">{Jason.encode!(output.content, pretty: true)}</pre>
              <div class="mt-4 flex gap-2">
                <button
                  id={"accept-ai-#{output.id}"}
                  phx-click="review"
                  phx-value-id={output.id}
                  phx-value-decision="accept"
                  class="btn-primary"
                >Accept</button>
                <button
                  id={"reject-ai-#{output.id}"}
                  phx-click="review"
                  phx-value-id={output.id}
                  phx-value-decision="reject"
                  class="btn-secondary"
                >Reject</button>
              </div>
            </article>
          </section>

          <section class="content-card" id="ai-natural-search">
            <h2 class="text-lg font-bold">Natural-language document search</h2>
            <.form for={@search_form} id="ai-search-form" phx-submit="search" class="mt-4 flex gap-3">
              <.input
                field={@search_form[:query]}
                placeholder="e.g. sale agreement for the Karen property"
              />
              <.button id="ai-search-button" class="btn-primary">Search</.button>
            </.form>
            <div id="ai-search-results" class="mt-4 grid gap-2">
              <.link
                :for={document <- @search_results}
                id={"ai-search-result-#{document.id}"}
                navigate={~p"/documents/#{document}"}
                class="rounded-xl border border-slate-200 p-3 hover:border-amber-400"
              >
                <strong>{document.title}</strong><span class="block text-xs text-slate-500">{document.client.name}</span>
              </.link>
            </div>
          </section>
        </div>

        <aside class="content-card h-fit" id="ai-settings-panel">
          <h2 class="font-bold">Firm AI controls</h2><p class="mt-1 text-xs leading-5 text-slate-500">
            Client data is sent only after an authorised firm opt-in.
          </p>
          <.form
            for={@settings_form}
            id="ai-settings-form"
            phx-submit="save-settings"
            class="mt-4 space-y-4"
          >
            <.input field={@settings_form[:enabled]} type="checkbox" label="Enable AI for the firm" />
            <.input field={@settings_form[:model]} label="Claude model" />
            <.button id="save-ai-settings" class="btn-secondary">Save controls</.button>
          </.form>
        </aside>
      </div>
    </Layouts.app>
    """
  end
end
