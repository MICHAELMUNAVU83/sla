defmodule SlaWeb.IntegrationLive.Index do
  use SlaWeb, :live_view
  alias Sla.Integrations

  def mount(_, _, socket), do: {:ok, load(socket)}

  def handle_event("enable", %{"provider" => provider}, socket) do
    case Integrations.configure(socket.assigns.current_scope.user, provider, %{}) do
      {:ok, _} ->
        {:noreply,
         load(socket)
         |> put_flash(
           :info,
           "#{provider} enabled. Add credentials through runtime configuration."
         )}

      {:error, :forbidden} ->
        {:noreply,
         put_flash(socket, :error, "Only partners and admins can configure integrations.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Could not configure: #{inspect(changeset.errors)}")}
    end
  end

  defp load(socket),
    do:
      assign(socket,
        connections: Integrations.list_connections(),
        events: Integrations.list_events(),
        providers: Sla.Integrations.Connection.providers()
      )

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Integrations" eyebrow="Secure external services" />
      <section id="integration-catalog" class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <article
          :for={provider <- @providers}
          id={"integration-#{provider}"}
          class="content-card group transition hover:-translate-y-0.5 hover:shadow-lg"
        >
          <div class="flex items-start justify-between">
            <div>
              <p class="text-xs font-bold uppercase tracking-wider text-amber-700">Provider</p><h2 class="mt-1 text-lg font-bold capitalize">
                {String.replace(provider, "_", " ")}
              </h2>
            </div>
            <span class={[
              "rounded-full px-2.5 py-1 text-xs font-bold",
              Enum.any?(@connections, &(&1.provider == provider && &1.status == "connected")) &&
                "bg-emerald-100 text-emerald-800",
              !Enum.any?(@connections, &(&1.provider == provider && &1.status == "connected")) &&
                "bg-slate-100 text-slate-600"
            ]}>{if Enum.any?(@connections, &(&1.provider == provider && &1.status == "connected")),
              do: "Enabled",
              else: "Off"}</span>
          </div>
          <button
            id={"enable-#{provider}"}
            phx-click="enable"
            phx-value-provider={provider}
            class="btn-secondary mt-5"
          >Enable integration</button>
        </article>
      </section>
      <section id="integration-events" class="content-card mt-8">
        <h2 class="text-lg font-bold">Recent webhook activity</h2>
        <div class="mt-4 divide-y divide-slate-100">
          <div
            :for={event <- @events}
            id={"integration-event-#{event.id}"}
            class="flex items-center justify-between gap-4 py-3 text-sm"
          >
            <span><strong class="capitalize">{event.provider}</strong> · {event.kind}</span><span class="rounded-full bg-slate-100 px-2 py-1 text-xs">{event.status}</span>
          </div><p
            :if={@events == []}
            id="integration-events-empty"
            class="py-8 text-center text-sm text-slate-500"
          >
            No callbacks received yet.
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
