# SLA Practice ERP — Tasks

Task breakdown for [PROJECT.md](PROJECT.md). Check items off as they're done. Run `mix precommit` before closing each task.

Legend: ⭐ = gap from Be Corp (top priority)

---

## M0 — Foundation (2 wks)

### Setup
- [x] Add deps: `oban`, `chromic_pdf`, `ex_aws` + `ex_aws_s3` (or `req_s3`), `money`/`decimal` handling
- [x] Configure Oban (queues: `default`, `reminders`, `mailers`, `pdf`, `ai`, `ocr`)
- [x] Set up S3-compatible storage config (dev: local/MinIO)
- [x] Brand Tailwind theme (SLA colours, logo, typography) and app shell layout with sidebar nav

### Auth & roles
- [x] `mix phx.gen.auth Accounts User users` (LiveView, scopes)
- [x] Add `role` to users: `partner | advocate | associate | clerk | accounts | admin`
- [x] Authorization module (`Sla.Policy`) with per-role permissions
- [x] Admin LiveView: invite/manage users, set roles, deactivate
- [x] 2FA (TOTP) for all users

### Clients
- [x] `Clients` context + `clients` table (type, name, KRA PIN, ID/reg no., email, phone, address, KYC status)
- [x] `client_contacts` table (for company clients)
- [x] Clients index LiveView (stream, search, filter by type)
- [x] Client create/edit form
- [x] Client show page (overview tabs: Matters, Documents, Financials, Activity)

### Matters (Files)
- [x] `Matters` context + `matters` table (client_id, file_number, title, practice_area, status, responsible_advocate_id, opened_on, closed_on, court, case_number)
- [x] `matter_members` join table (team assignment)
- [x] File-number generator (e.g. `SLA/RE/2026/0142`, sequence per practice area per year)
- [x] Matters index LiveView (filters: status, practice area, advocate, client)
- [x] Matter create/edit form
- [x] Matter show page shell (tabs: Overview, Activity, Documents, Billing, Tasks, Calendar)
- [x] `matter_parties` (opposing party, opposing counsel, court, other)

### Tests
- [x] Context tests for Clients, Matters, file numbering
- [x] LiveView tests for client/matter CRUD

---

## M1 — File Tracker & Bring-Up ⭐ (2 wks)

### Activity log
- [x] `Tracker` context + `file_activities` table (matter_id, user_id, action_type, note, occurred_at, document_id?, email_ref?)
- [x] Action types: email sent, email received, call, meeting, filing, court attendance, letter, document received, note, other
- [x] "Log activity" form on matter page (quick-add)
- [x] Activity timeline on matter page (stream, newest first)
- [x] Append-only: no edit/delete after 24h (corrections as new entries)
- [x] **Latest action banner** on matter page
- [x] Latest action column on matters index (denormalised `last_activity_at` / `last_activity_summary` on matters)

### Bring-ups / reminders
- [x] `bring_ups` table (matter_id, activity_id?, assignee_id, created_by_id, due_on, note, status: pending/done/snoozed/cancelled, completed_at)
- [x] "Bring up in…" option on activity form (1, 3, 7, 14, 30 days, custom)
- [x] Assign bring-up to self or another user
- [x] **My Diary** LiveView: overdue / today / upcoming sections
- [x] Actions: complete (prompts to log new activity), snooze, reassign, cancel
- [x] Firm-wide diary view for partners (filter by user)
- [x] Real-time updates via PubSub

### Notifications
- [x] `notifications` table + in-app bell with unread count
- [x] Oban cron: daily morning digest email (due today + overdue)
- [x] Oban job: notify at due date
- [x] Escalation: overdue > N days → notify responsible partner (configurable N)
- [x] Dormant file job: open matter with no activity for 30/60/90 days → flag + notify
- [x] User notification preferences (in-app/email; SMS/WhatsApp later)

### Tests
- [x] Tracker context tests (activity creation updates latest action, bring-up lifecycle)
- [x] Oban job tests (digest, escalation, dormant) with `Oban.Testing`
- [x] My Diary LiveView tests

---

## M2 — Documents (Client → Matter → Category) ⭐ (2 wks)

- [x] `Documents` context + `documents` table (client_id, matter_id?, category_id, title, tags, current_version_id, uploaded_by_id)
- [x] `document_versions` table (document_id, storage_key, filename, content_type, size, checksum, version_no, uploaded_by_id)
- [x] `document_categories` (seed defaults: Pleadings, Correspondence, Agreements, Court Orders, Title Documents, KYC, Invoices & Receipts, Evidence, Internal Notes; configurable per practice area)
- [x] LiveView uploads direct to S3 (presigned), drag-and-drop, multiple files
- [x] Folder tree navigation: Client → Matter → Category, plus "General / Client-level"
- [x] Documents tab on matter and client pages
- [x] Move/recategorise documents
- [x] Version upload + history + restore
- [x] Preview PDFs/images in-app; download via signed URLs
- [x] Per-matter access control (only team members + partners)
- [x] Postgres full-text search on title, tags, extracted text
- [x] Global document search with filters (client, matter, category, date, uploader)
- [x] Log document uploads to file activity timeline
- [x] Tests: context, upload flow, access control

---

## M3 — Billing ⭐ (3 wks)

### Fee agreements
- [x] `fee_agreements` table (matter_id, type: fixed/hourly/aro_scale/retainer/milestone, amount, currency, terms)
- [x] `rates` per user role/user (hourly)
- [x] Fee agreement form on matter page

### Time & disbursements
- [x] `time_entries` (matter_id, user_id, date, minutes, rate, description, billable, invoice_line_id?)
- [ ] Timer component (start/stop, persists across navigation)
- [x] `disbursements` (matter_id, date, type, amount, vat_applicable, receipt document, rebillable, invoice_line_id?)
- [x] Unbilled WIP list per matter

### Invoices
- [x] `invoices` (client_id, matter_id, number, type: proforma/tax/credit_note, status: draft/approved/issued/paid/partially_paid/void, currency, issued_on, due_on, subtotal, vat, total)
- [x] `invoice_lines` (description, qty, unit_price, vat_rate, source: time/disbursement/fixed)
- [x] Sequential numbering per document type (DB-safe)
- [x] Build invoice from unbilled WIP
- [x] VAT 16% on fees, disbursements optionally exempt
- [x] Approval workflow (draft → partner approval → issue)
- [ ] Invoice HEEx template (firm branding, bank details, KRA PIN)
- [ ] PDF generation via ChromicPDF (Oban job); auto-file into matter Documents → Invoices & Receipts
- [ ] Email invoice to client

### Payments & receipts
- [x] `payments` (client_id, method: bank/cheque/mpesa/card/cash, reference, amount, currency, received_on, withholding_tax)
- [x] `payment_allocations` (payment → invoices)
- [ ] Auto-generate Receipt (number, PDF template) on payment
- [ ] Credit note template and flow
- [ ] Statement of Account template (per client / per matter)

### Fee summaries
- [ ] Matter financial summary card: agreed, billed, paid, outstanding, WIP, disbursements, trust balance
- [ ] Client financial summary rolling up all matters with drill-down
- [x] Aged debtors report (0–30, 31–60, 61–90, 90+)
- [ ] Automated payment reminder emails (Oban)

### Tests
- [ ] Invoice totals/VAT calculations, numbering concurrency, allocation, receipt generation
- [ ] LiveView tests for invoice builder and payment recording

---

## M4 — Accounts & Reports (2 wks)

- [x] `ledger_entries` with `account: client | office` (double-entry style)
- [x] Client (trust) account deposits/withdrawals per matter
- [x] Client → office transfer against issued invoice (audited, partner approval)
- [x] Block office spending from client money; negative trust balance prevention
- [ ] Bank reconciliation import (CSV)
- [ ] Dashboards: revenue, collections, WIP, matters by practice area, advocate productivity, matter ageing
- [ ] CSV/Excel export for all reports
- [ ] Audit log table + viewer (views, edits, downloads, money movements)

---

## M5 — Practice Management (3 wks)

- [x] Client intake form
- [x] Conflict check search (clients, parties, opposing counsel) required before matter open; result stored
- [x] KYC checklist + documents (ID, KRA PIN, CR12, beneficial ownership); risk rating
- [x] `calendar_events` (hearings, mentions, deadlines, meetings) on matter + firm calendar
- [x] Court diary / cause-list view
- [x] Deadline rules engine (e.g. +15 days to enter appearance) → auto bring-ups
- [x] Google/Outlook calendar sync
- [x] `tasks` with assignee, due date, status; matter task tab
- [x] Workflow templates per matter type (e.g. Conveyance – Purchase) generating tasks/checklists
- [x] Document assembly: templates with merge fields (client, matter, parties) → DOCX/PDF
- [x] Ethical walls (exclude users from specific matters)
- [x] Matter closing checklist + archive with retention date

---

## M6 — Intelligence / AI (3 wks)

- [ ] `AI` context wrapping Claude API via `Req` (config, retries, token logging, per-firm opt-in)
- [ ] Matter summary ("Where are we?") from activities, documents, emails — cached, regenerate on demand
- [ ] Suggested next action + bring-up date after logging an activity
- [ ] Document auto-classification (category + suggested matter) on upload
- [ ] OCR pipeline for scanned PDFs (Oban job) → extracted text for search
- [ ] Key data extraction (parties, dates, amounts, title numbers) → review/accept UI
- [ ] Document summarisation
- [ ] Drafting assistant (letters, demand notices, follow-up emails) with matter context
- [ ] Smart time capture suggestions
- [ ] Natural-language search (pgvector embeddings)
- [ ] Collections insight + reminder drafts
- [ ] Human-review UI for all AI outputs; AI action audit log

---

## M7 — Integrations (3–4 wks)

- [x] M-Pesa Daraja: STK push, C2B paybill callback → auto payment + receipt
- [x] KRA eTIMS: submit tax invoices, store control number/QR on PDF
- [x] Gmail/Outlook integration: file emails to matter → auto activity
- [x] Client portal (separate auth): matter status, shared docs, invoices, pay via M-Pesa, secure messages
- [x] E-signature for engagement letters/agreements
- [x] SMS/WhatsApp notifications (Africa's Talking / WhatsApp Business API)
- [x] Accounting export/sync (QuickBooks / Sage / Xero — confirm which)

---

## Data Migration from Be Corp

- [ ] Obtain export of clients, matters, documents, balances
- [ ] Import scripts (mix task) for clients and matters
- [ ] Document import with client/matter mapping (AI-assisted for unlabelled files)
- [ ] Manual review screen for mapping before commit
- [ ] Import opening balances (paid / outstanding per matter)
- [ ] Dry run on staging, sign-off, go-live

---

## Cross-cutting

- [ ] Kenya Data Protection Act compliance: consent, data retention, access requests, encryption at rest
- [ ] Backups + restore drill
- [ ] Error tracking & monitoring
- [ ] Staging and production deployment (Fly.io or local DC — decide)
- [ ] User guide / training for staff

## Open Questions (blockers)

- [ ] Confirm file-numbering convention
- [ ] Confirm most-used fee structures
- [ ] eTIMS registration status + current accounting system
- [ ] Preferred notification channels
- [ ] Client portal in first release?
- [ ] Data hosting constraints
