defmodule SlaWeb.PortalLive.Index do
  use SlaWeb, :live_view
  alias Sla.{Integrations, Repo}
  alias Sla.Integrations.PortalAccount

  def mount(_, session, socket) do
    case session["portal_account_id"] && Repo.get(PortalAccount, session["portal_account_id"]) do
      %PortalAccount{active: true} = account ->
        {:ok, assign(socket, snapshot: Integrations.portal_snapshot(account), account: account)}

      _ ->
        {:ok, socket |> put_flash(:error, "Please sign in") |> redirect(to: ~p"/portal/log-in")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="client-portal" class="space-y-8">
        <.page_header title={"Hello, #{@snapshot.client.name}"} eyebrow="Client portal">
          <:actions>
            <.link href={~p"/portal/log-out"} method="delete" class="btn-secondary">Sign out</.link>
          </:actions>
        </.page_header>
        <section id="portal-matters" class="grid gap-4 md:grid-cols-2">
          <article
            :for={matter <- @snapshot.matters}
            id={"portal-matter-#{matter.id}"}
            class="content-card"
          >
            <p class="text-xs font-bold text-amber-700">{matter.file_number}</p><h2 class="mt-2 text-lg font-bold">
              {matter.title}
            </h2>
            <span class="mt-4 inline-flex rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold">{matter.status}</span>
          </article>
        </section>
        <section id="portal-invoices" class="content-card">
          <h2 class="text-lg font-bold">Invoices</h2>
          <div class="mt-4 divide-y divide-slate-100">
            <div
              :for={invoice <- @snapshot.invoices}
              id={"portal-invoice-#{invoice.id}"}
              class="flex justify-between py-4"
            >
              <span>{invoice.number || "Draft"}</span><strong>{invoice.currency} {invoice.total}</strong>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
