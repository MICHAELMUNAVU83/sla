defmodule SlaWeb.ReportsLive.Index do
  use SlaWeb, :live_view
  alias Sla.{AccountsFinance, Billing, Matters}

  def mount(_, _, socket) do
    invoices = Billing.list_invoices()
    matters = Matters.list_matters_for_user(socket.assigns.current_scope.user)
    revenue = Enum.reduce(invoices, Decimal.new(0), &Decimal.add(&2, &1.total))

    collections =
      Enum.reduce(invoices, Decimal.new(0), fn invoice, acc ->
        Decimal.add(acc, Decimal.sub(invoice.total, Billing.outstanding(invoice)))
      end)

    {:ok,
     assign(socket,
       invoices: invoices,
       matters: matters,
       revenue: revenue,
       collections: collections,
       entries: AccountsFinance.list_entries(),
       audits: AccountsFinance.list_audit_logs()
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Accounts & reports" eyebrow="Financial control centre" />
      <div id="report-dashboard" class="detail-grid">
        <div class="detail-card">
          <span>Revenue billed</span><strong>KES {Decimal.round(@revenue, 2)}</strong>
        </div><div class="detail-card">
          <span>Collections</span><strong>KES {Decimal.round(@collections, 2)}</strong>
        </div><div class="detail-card">
          <span>Active matters</span><strong>{Enum.count(@matters, &(&1.status == "open"))}</strong>
        </div>
      </div>
      <div class="grid gap-6 lg:grid-cols-2">
        <section id="ledger-entries" class="content-card">
          <h2 class="mb-4 text-lg font-bold">Client & office ledgers</h2><div
            :for={entry <- @entries}
            id={"ledger-entry-#{entry.id}"}
            class="border-t border-slate-200 py-3 text-sm"
          >
            <strong>{entry.account} · {entry.direction}</strong><span class="float-right">{entry.currency} {entry.amount}</span><p class="text-slate-500">
              {entry.matter.file_number} · {entry.description}
            </p>
          </div><div :if={@entries == []} class="empty-state">No ledger movements yet.</div>
        </section>
        <section id="audit-log" class="content-card">
          <h2 class="mb-4 text-lg font-bold">Audit trail</h2><div
            :for={audit <- @audits}
            id={"audit-#{audit.id}"}
            class="border-t border-slate-200 py-3 text-sm"
          >
            <strong>{audit.action}</strong><span class="float-right">{Calendar.strftime(
              audit.occurred_at,
              "%d %b %Y %H:%M"
            )}</span><p class="text-slate-500">{audit.entity_type} #{audit.entity_id}</p>
          </div><div :if={@audits == []} class="empty-state">No audited events yet.</div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
