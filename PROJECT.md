# SLA Practice ERP — Project Plan

An intelligent practice-management ERP for **Sichangi Law Alliance LLP**, built on Phoenix 1.8 / LiveView, Ecto + Postgres, Tailwind v4.

It covers the gaps found in the current Be Corp app, plus features that established legal systems (Clio, PracticePanther, MyCase, LEAP, Smokeball, Actionstep, and Kenyan tools such as Lawfirm360 / Advocate Diary) treat as standard.

---

## 1. Goals

- **One place per matter.** Anyone in the firm can open a file and see its current state, its last action, its next step, its documents and its money.
- **Nothing slips.** Reminders, court dates and limitation periods come up automatically.
- **Get paid.** Time and disbursements become invoices, invoices become receipts, and every client and matter shows paid against outstanding fees.
- **Compliance by default.** Advocates (Practice) Rules, Advocates Accounts Rules (client vs office money), KRA eTIMS invoicing, VAT 16% and withholding tax, and the Kenya Data Protection Act 2019.
- **Intelligence where it saves time.** Use AI (Claude) for summaries, drafting, document classification and suggested next actions, always with a human in the loop.

---

## 2. Core Domain Model

```
Client ─┬─< Matter (File) ─┬─< FileActivity (bring-up log)
        │                  ├─< Reminder / BringUp
        │                  ├─< Document ─< DocumentVersion
        │                  ├─< TimeEntry
        │                  ├─< Disbursement / Expense
        │                  ├─< Invoice ─< InvoiceLine
        │                  │            └─< Payment ─> Receipt
        │                  ├─< Task
        │                  ├─< CalendarEvent (court dates, meetings)
        │                  ├─< MatterParty (opposing party, counsel, court)
        │                  └─  FeeAgreement (fixed / hourly / ARO scale / contingency)
        └─< ClientContact
User (Advocate / Associate / Clerk / Accounts / Admin) ── assigned to Matters
TrustLedger (client account) / OfficeLedger
```

Key fields:
- **Client**: type (individual/company), KRA PIN, ID/registration no., contacts, KYC status, conflict-check result.
- **Matter**: file number (e.g. `SLA/RE/2026/0142`), practice area (Real Estate, Banking & Finance, Dispute Resolution, Corporate & Commercial), responsible advocate, team, status (open / dormant / closed / archived), opened/closed dates, court and case number, fee arrangement.

---

## 3. Feature Set

### Phase 1: Required (gaps in Be Corp)

#### 3.1 File Tracker and Bring-Up / Reminder System ⭐
- **Activity log per file**: a timestamped, append-only entry for every action, e.g. "Sent follow-up email to client", "Filed defence at Milimani", "Received title from Lands". Fields: action type, note, author, date, linked document or email.
- **"Latest action" banner** at the top of every matter and in the matters list, so a colleague can pick up the file when the associate is away.
- **Bring-ups**: when logging an action, optionally "bring up in N days" (presets: 1, 3, 7, 14, 30, or a custom date). This creates a reminder for the author or another assignee.
- **Bring-up dashboard** ("My Diary"): today, overdue and upcoming, with actions to snooze, complete (which logs a new activity), or reassign.
- Notifications in-app, by email and optionally by SMS/WhatsApp. A daily digest each morning.
- **Escalation**: overdue more than X days notifies the responsible partner.
- **Dormant file alert**: no activity on an open matter for 30/60/90 days.
- Implementation: `Oban` cron jobs for due reminders and digests; PubSub for live dashboard updates.

#### 3.2 Invoice and Receipt Templates ⭐
- Firm-branded templates for **Fee Note / Pro-forma Invoice**, **Tax Invoice**, **Receipt**, **Credit Note** and **Statement of Account**.
- Build invoices from unbilled time entries, disbursements and fixed fees on a matter.
- VAT 16% on fees (disbursements optionally exempt), withholding tax deduction on receipts, multi-currency (KES/USD).
- Sequential numbering per document type; drafts, then approval, then issue.
- PDF generation (ChromicPDF or Typst), email to client from the app, and a stored copy filed under the matter's documents.
- **KRA eTIMS integration** so tax invoices carry the control unit/QR (later in the phase).
- Record payments (bank, cheque, M-Pesa, card). This automatically issues a receipt and allocates the payment to invoices.

#### 3.3 Legal Fees per Client and per Matter ⭐
- **Fee agreement per matter**: fixed fee, hourly rates (per user role), Advocates Remuneration Order scale, retainer, or staged/milestone.
- **Matter financial summary**: agreed fee, billed, paid, outstanding, unbilled work in progress, disbursements and trust balance.
- **Client financial summary**: rolls up all matters, with a drill-down into each.
- **Aged debtors report** (0–30, 31–60, 61–90, 90+ days) and automated payment reminders.
- **Client (trust) account vs office account** ledgers that comply with the Advocates Accounts Rules. Money is never mixed, and transfers from client to office money are audited.

#### 3.4 Document Management Grouped by Client → Matter ⭐
- Folder tree: **Client → Matter → Category** (Pleadings, Correspondence, Agreements, Court Orders, Title Documents, KYC, Invoices & Receipts, Evidence, Internal Notes). Categories can be configured per practice area.
- Documents with no matter go into a "General / Client-level" folder.
- Tags, version history, check-in/check-out, upload by drag and drop, preview of PDFs and images.
- Full-text search including OCR of scanned documents, with filters for client, matter, category, date and uploader.
- Storage in S3-compatible object storage with signed URLs; per-matter access control.
- **AI auto-classification**: an uploaded file is categorised and gets a suggested matter.

### Phase 2: Standard Practice Management (from Clio / PracticePanther / LEAP)

| Feature | Description |
|---|---|
| **Client intake and conflict check** | Intake form, then a conflict search across clients, parties and opposing counsel before a matter opens. |
| **KYC / AML** | Capture ID, KRA PIN, CR12 and beneficial ownership; flag high-risk clients (Proceeds of Crime and Anti-Money Laundering Act). |
| **Time tracking** | One-click timers, manual entries, billable vs non-billable, utilisation reports. |
| **Expenses / disbursements** | Court fees, stamp duty, search fees, travel; receipts attached; rebillable to the matter. |
| **Calendar and court diary** | Hearings, mentions, deadlines; sync with Google/Outlook; firm-wide cause-list view. |
| **Limitation and deadline rules** | Compute deadlines from court rules (e.g. 15 days to enter appearance), with automatic bring-ups. |
| **Tasks and workflows** | Templates per matter type (e.g. "Conveyance – Purchase": search → LCB consent → stamp duty → registration), with checklists and assignment. |
| **Document assembly** | Generate letters, demand notices, agreements and affidavits from templates merged with matter/client data. |
| **Email integration** | Gmail/Outlook. File emails to a matter, which automatically logs a file activity. |
| **Client portal** | Clients see matter status, shared documents, invoices and payments, and can pay by M-Pesa. Secure messaging. |
| **Payments** | M-Pesa STK push (Daraja), card and bank reconciliation. |
| **E-signatures** | Send engagement letters and agreements for signing. |
| **Reports and dashboards** | Revenue, WIP, collections, matters by practice area, advocate productivity, matter ageing. |
| **Roles and permissions** | Partner, Advocate, Associate, Paralegal/Clerk, Accounts, Admin; ethical walls per matter. |
| **Audit trail** | Every view, edit, download and money movement is logged. |
| **Matter closing and archiving** | Closing checklist, final account, retention period, then archive. |

### Phase 3: Intelligent Features (AI)

- **Matter summary**: a one-paragraph status generated from the activity log, documents and emails ("Where are we on this file?").
- **Suggested next action and bring-up**: after an activity is logged, suggest the logical next step and a date.
- **Document intelligence**: auto-classify, extract key data (parties, dates, amounts, title numbers), and summarise long documents.
- **Drafting assistant**: first drafts of letters, demand notices and follow-up emails using matter context.
- **Smart time capture**: suggest time entries from emails sent, documents edited and calendar events.
- **Natural-language search**: e.g. "show the sale agreement for the Karen property for client X".
- **Collections insight**: flag clients likely to pay late and draft reminder emails.
- **Kenya Law integration** (later): link cited cases and statutes from kenyalaw.org.

All AI outputs are suggestions that a user reviews. Client data stays within the firm's controls, in line with the Data Protection Act 2019 and advocate–client privilege.

---

## 4. Architecture

- **Phoenix 1.8 LiveView** for the UI; contexts: `Clients`, `Matters`, `Tracker` (activities + bring-ups), `Documents`, `Billing` (time, invoices, payments, receipts), `Accounts` (ledgers), `Calendar`, `Accounts/Auth`, `AI`.
- **Postgres** with full-text search (`tsvector`); `pgvector` for semantic search later.
- **Oban** for reminders, digests, PDF generation, OCR and AI jobs.
- **Req** for external APIs (Claude, M-Pesa Daraja, KRA eTIMS, Google/Microsoft).
- **Auth**: `mix phx.gen.auth` with scopes; 2FA for all users.
- **Storage**: S3-compatible (e.g. AWS S3 / Cloudflare R2), encryption at rest.
- **PDF**: ChromicPDF rendering HEEx templates.
- **Hosting**: Fly.io or a local data centre if data-residency requirements apply.

---

## 5. Delivery Roadmap

| Milestone | Scope | Est. |
|---|---|---|
| **M0 – Foundation** | Auth and roles, Clients, Matters, file numbering, UI shell | 2 wks |
| **M1 – File Tracker** | Activity log, latest-action banner, bring-ups, My Diary, Oban reminders and email digest | 2 wks |
| **M2 – Documents** | Client → Matter → Category tree, uploads, versions, search | 2 wks |
| **M3 – Billing** | Fee agreements, time and disbursements, invoice/receipt templates and PDF, payments, client/matter fee summaries | 3 wks |
| **M4 – Accounts and reports** | Client/office ledgers, aged debtors, dashboards | 2 wks |
| **M5 – Practice mgmt** | Calendar/court diary, tasks/workflows, conflict check, KYC | 3 wks |
| **M6 – Intelligence** | Matter summaries, next-action suggestions, document classification and extraction, drafting | 3 wks |
| **M7 – Integrations** | M-Pesa, eTIMS, email sync, client portal, e-signature | 3–4 wks |

---

## 6. Data Migration from Be Corp
- Export clients, matters and documents. Map each document to a client and matter (AI-assisted for unlabelled files), then review the mapping manually before go-live.
- Import opening balances per matter for fees paid and outstanding.

## 7. Open Questions
1. File-numbering convention currently used by the firm?
2. Which fee structures are used most often (ARO scale vs hourly vs fixed)?
3. Is the firm eTIMS-registered, and which accounting system is in use today (QuickBooks, Sage, Xero)?
4. Preferred notification channels (email, SMS, WhatsApp)?
5. Is a client portal wanted in the first release?
6. Data-hosting constraints (in-country vs cloud)?
