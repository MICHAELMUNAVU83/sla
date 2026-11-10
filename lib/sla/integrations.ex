defmodule Sla.Integrations do
  @moduledoc "Audited, idempotent boundaries for payments, tax, communications, signatures, and accounting."
  import Ecto.Query
  alias Sla.{Billing, Repo, Tracker}

  alias Sla.Integrations.{
    Connection,
    Event,
    PortalAccount,
    PortalMessage,
    Provider,
    SignatureRequest
  }

  def list_connections, do: Repo.all(from c in Connection, order_by: c.provider)
  def list_events, do: Repo.all(from e in Event, order_by: [desc: e.inserted_at], limit: 100)

  def configure(user, provider, settings) when user.role in ~w(partner admin) do
    connection =
      Repo.get_by(Connection, provider: provider) ||
        %Connection{provider: provider, created_by_id: user.id}

    connection
    |> Connection.changeset(%{status: "connected", settings: settings, last_error: nil})
    |> Repo.insert_or_update()
  end

  def configure(_, _, _), do: {:error, :forbidden}

  def initiate_stk(_client, amount, phone, reference) do
    Provider.request(:mpesa, :post, "/stkpush",
      json: %{
        phone: normalize_phone(phone),
        amount: Decimal.to_integer(Decimal.round(amount, 0)),
        account_reference: reference,
        callback_url: callback_url("mpesa")
      }
    )
  end

  def submit_etims(invoice) do
    payload = %{
      invoice_number: invoice.number,
      date: invoice.issued_on,
      currency: invoice.currency,
      subtotal: invoice.subtotal,
      tax: invoice.vat,
      total: invoice.total,
      buyer: %{name: invoice.client.name, pin: invoice.client.kra_pin},
      lines:
        Enum.map(
          invoice.lines,
          &%{
            description: &1.description,
            quantity: &1.quantity,
            unit_price: &1.unit_price,
            tax_rate: &1.vat_rate
          }
        )
    }

    with {:ok, response} <- Provider.request(:etims, :post, "/invoices", json: payload),
         control when is_binary(control) <- response["control_number"] do
      invoice
      |> Ecto.Changeset.change(
        etims_control_number: control,
        etims_qr_data: response["qr_data"],
        etims_status: "accepted",
        etims_submitted_at: DateTime.utc_now(:second)
      )
      |> Repo.update()
    else
      {:error, reason} -> mark_etims_failed(invoice, reason)
      _ -> mark_etims_failed(invoice, :invalid_response)
    end
  end

  def receive(provider, external_id, kind, payload, processor \\ &default_processor/1) do
    case Repo.get_by(Event, provider: provider, external_id: external_id) do
      %Event{} = event ->
        {:ok, event, :duplicate}

      nil ->
        Repo.transact(fn ->
          event =
            Repo.insert!(
              Event.changeset(%Event{}, %{
                provider: provider,
                external_id: external_id,
                kind: kind,
                payload: payload
              })
            )

          case processor.(event) do
            {:ok, result} ->
              {:ok,
               event
               |> Event.changeset(%{
                 status: "processed",
                 result: stringify(result),
                 processed_at: DateTime.utc_now(:second)
               })
               |> Repo.update!()}

            {:error, reason} ->
              {:error,
               event
               |> Event.changeset(%{
                 status: "failed",
                 error: inspect(reason),
                 processed_at: DateTime.utc_now(:second)
               })
               |> Repo.update!()}
          end
        end)
    end
  end

  def process_mpesa(%Event{payload: payload}) do
    with client_id when not is_nil(client_id) <- payload["client_id"],
         client <- Sla.Clients.get_client!(client_id),
         amount when not is_nil(amount) <- payload["amount"] do
      Billing.record_payment(
        nil,
        client,
        %{
          method: "mpesa",
          reference: payload["receipt"],
          amount: amount,
          currency: "KES",
          received_on: Date.utc_today(),
          external_provider: "mpesa",
          external_id: payload["transaction_id"],
          phone: payload["phone"]
        },
        []
      )
      |> case do
        {:ok, %{payment: payment}} ->
          {:ok, %{payment_id: payment.id, receipt: payment.receipt_number}}

        {:error, _, reason, _} ->
          {:error, reason}
      end
    else
      _ -> {:error, :invalid_callback}
    end
  end

  def file_email(matter, user, message) do
    Tracker.create_activity(matter, user, %{
      action_type: direction(message),
      note: email_note(message),
      occurred_at: message["sent_at"],
      email_ref: message["id"]
    })
  end

  def create_portal_account(client, attrs),
    do:
      %PortalAccount{client_id: client.id}
      |> PortalAccount.registration_changeset(attrs)
      |> Repo.insert()

  def authenticate_portal(email, password) do
    account = Repo.get_by(PortalAccount, email: String.downcase(String.trim(email)))

    if PortalAccount.valid_password?(account, password),
      do: {:ok, Repo.preload(account, :client)},
      else: {:error, :invalid_credentials}
  end

  def portal_snapshot(%PortalAccount{client_id: client_id}) do
    %{
      client: Sla.Clients.get_client!(client_id),
      invoices:
        Repo.all(
          from i in Sla.Billing.Invoice,
            where:
              i.client_id == ^client_id and
                i.status in ["issued", "partially_paid", "paid"],
            order_by: [desc: i.inserted_at]
        ),
      matters:
        Repo.all(
          from m in Sla.Matters.Matter, where: m.client_id == ^client_id, order_by: m.file_number
        ),
      documents:
        Repo.all(
          from d in Sla.Documents.Document,
            where: d.client_id == ^client_id and d.portal_visible,
            order_by: [desc: d.inserted_at]
        ),
      messages:
        Repo.all(
          from m in PortalMessage,
            where: m.client_id == ^client_id,
            order_by: [desc: m.inserted_at],
            preload: [:matter]
        )
    }
  end

  def send_message(%PortalAccount{} = account, matter, body)
      when matter.client_id == account.client_id,
      do:
        %PortalMessage{
          client_id: account.client_id,
          matter_id: matter.id,
          portal_account_id: account.id,
          from_client: true
        }
        |> PortalMessage.changeset(%{body: body})
        |> Repo.insert()

  def send_message(_, _, _), do: {:error, :forbidden}

  def request_signature(user, document, attrs) do
    request = %SignatureRequest{
      document_id: document.id,
      matter_id: document.matter_id,
      requested_by_id: user.id
    }

    with {:ok, request} <- request |> SignatureRequest.changeset(attrs) |> Repo.insert(),
         {:ok, response} <-
           Provider.request(:docusign, :post, "/envelopes",
             json: %{
               document_id: document.id,
               signer_name: request.signer_name,
               signer_email: request.signer_email,
               callback_url: callback_url("docusign")
             }
           ) do
      request
      |> SignatureRequest.changeset(%{
        external_id: response["id"],
        status: "sent",
        sent_at: DateTime.utc_now(:second)
      })
      |> Repo.update()
    end
  end

  def notify(channel, recipient, body) when channel in ~w(africastalking whatsapp),
    do:
      Provider.request(
        %{"africastalking" => :africastalking, "whatsapp" => :whatsapp}[channel],
        :post,
        "/messages",
        json: %{to: recipient, body: body}
      )

  def notify(_, _, _), do: {:error, :unsupported_channel}

  def export_accounting(provider, invoices),
    do:
      Provider.request(provider, :post, "/invoices/batch",
        json: %{
          invoices:
            Enum.map(invoices, &%{number: &1.number, total: &1.total, currency: &1.currency})
        }
      )

  defp default_processor(event),
    do: if(event.provider == "mpesa", do: process_mpesa(event), else: {:ok, %{accepted: true}})

  defp mark_etims_failed(invoice, reason) do
    case invoice |> Ecto.Changeset.change(etims_status: "failed") |> Repo.update() do
      {:ok, _} -> {:error, reason}
      error -> error
    end
  end

  defp normalize_phone("0" <> rest), do: "254" <> rest
  defp normalize_phone("+" <> rest), do: rest
  defp normalize_phone(phone), do: phone
  defp callback_url(provider), do: SlaWeb.Endpoint.url() <> "/webhooks/" <> provider
  defp direction(%{"direction" => "inbound"}), do: "email received"
  defp direction(_), do: "email sent"
  defp email_note(message), do: "Email: #{message["subject"] || "(no subject)"}"
  defp stringify(value), do: Jason.decode!(Jason.encode!(value))
end
