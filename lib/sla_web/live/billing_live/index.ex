defmodule SlaWeb.BillingLive.Index do
  use SlaWeb, :live_view
  alias Sla.Billing

  def mount(_, _, socket),
    do: {:ok, assign(socket, invoices: Billing.list_invoices(), aged: Billing.aged_debtors())}

  def handle_event("approve", %{"id" => id}, socket) do
    invoice = Billing.get_invoice!(id)

    case Billing.approve_invoice(invoice, socket.assigns.current_scope.user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(invoices: Billing.list_invoices(), aged: Billing.aged_debtors())
         |> put_flash(:info, "Invoice approved.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Partner approval is required.")}
    end
  end

  def handle_event("issue", %{"id" => id}, socket) do
    case Billing.issue_invoice(Billing.get_invoice!(id), socket.assigns.current_scope.user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(invoices: Billing.list_invoices(), aged: Billing.aged_debtors())
         |> put_flash(:info, "Invoice issued.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Billing" eyebrow="Fees, invoices and receipts">
        <:actions>
          <.link id="billing-reports" navigate={~p"/reports"} class="btn-secondary">Reports & accounts</.link>
        </:actions>
      </.page_header>
      <div id="invoice-list" class="content-card overflow-x-auto">
        <table class="w-full text-left text-sm">
          <thead>
            <tr>
              <th>Invoice</th><th>Client / matter</th><th>Status</th><th>Total</th><th>
                Outstanding
              </th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={invoice <- @invoices}
              id={"invoice-#{invoice.id}"}
              class="border-t border-slate-200"
            >
              <td class="py-4 font-bold">{invoice.number || "Draft ##{invoice.id}"}</td><td>
                {invoice.client.name}<br /><span class="text-slate-500">{invoice.matter.file_number}</span>
              </td><td>{invoice.status}</td><td>
                {invoice.currency} {Decimal.round(invoice.total, 2)}
              </td><td>{invoice.currency} {Decimal.round(Billing.outstanding(invoice), 2)}</td>
              <td>
                <button
                  :if={invoice.status == "draft"}
                  id={"approve-invoice-#{invoice.id}"}
                  phx-click="approve"
                  phx-value-id={invoice.id}
                  class="btn-secondary"
                >Approve</button>
                <button
                  :if={invoice.status == "approved"}
                  id={"issue-invoice-#{invoice.id}"}
                  phx-click="issue"
                  phx-value-id={invoice.id}
                  class="btn-primary"
                >Issue</button>
              </td>
            </tr>
          </tbody>
        </table>
        <div :if={@invoices == []} id="invoice-list-empty" class="empty-state">
          No invoices yet. Build one from a matter's Billing tab.
        </div>
      </div>
      <section id="aged-debtors" class="content-card mt-6">
        <h2 class="mb-4 text-lg font-bold">Aged debtors</h2><div class="grid gap-3 md:grid-cols-4">
          <div :for={bucket <- ["0–30", "31–60", "61–90", "90+"]} class="detail-card">
            <span>{bucket} days</span><strong>{Enum.count(@aged, &(&1.age_bucket == bucket))} invoices</strong>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
