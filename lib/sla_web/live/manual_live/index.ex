defmodule SlaWeb.ManualLive.Index do
  @moduledoc """
  In-app user manual. Each section has plain-language steps and screenshots.

  Screenshots live in `priv/static/images/manual` and are produced by
  `scripts/manual/capture.js`. When a feature is added or changed, update the
  matching section here and re-run the capture script (see AGENTS.md).
  """
  use SlaWeb, :live_view

  @sections [
    %{
      id: "getting-started",
      title: "Getting started",
      intro:
        "The system keeps the firm's clients, cases, deadlines, documents and fees in one place. Use the menu on the left to move between areas.",
      steps: [
        "Sign in with your work email and password, or ask for a one-time sign-in link.",
        "The menu on the left lists the main areas. Your name and role are shown at the bottom.",
        "Anything you add or change opens in a popup. Fill it in and press the dark button to save, or Cancel to close it without saving.",
        "The bell at the top right shows reminders and alerts meant for you."
      ],
      shots: []
    },
    %{
      id: "clients",
      title: "Client management",
      intro: "Every client the firm acts for, with their contact details and compliance checks.",
      steps: [
        "Open Client management to see all clients. Use the search box to find a client by name, email or KRA PIN.",
        "Press New client, fill in the client's details and press Save client.",
        "Open a client to see their cases, documents and compliance status.",
        "On the Compliance tab, press Update review to record the KYC checks (ID, KRA PIN, CR12, beneficial owners, source of funds) and a risk rating."
      ],
      shots: [
        {"clients.png", "The client list"},
        {"client-new.png", "Adding a new client"},
        {"client-kyc.png", "A client's compliance (KYC) review"}
      ]
    },
    %{
      id: "cases",
      title: "Case management",
      intro:
        "Each case (matter) has its own file with a file number, history, documents, fees, tasks and dates.",
      steps: [
        "Open Case management to see all open files. Filter by status, practice area, advocate or client.",
        "Press New matter, choose the client, give the matter a title and press Save matter. A file number is created automatically.",
        "Open a matter to see its details. The Latest action box shows the most recent thing that happened on the file.",
        "Use the tabs (Activity, Documents, Billing, Tasks, Calendar) to work on the file. Press Edit file to change its details."
      ],
      shots: [
        {"matters.png", "The list of matters"},
        {"matter-overview.png", "A matter file"}
      ]
    },
    %{
      id: "bring-ups",
      title: "Bring-up system",
      intro:
        "Bring-ups are reminders to come back to a file on a set date, so nothing is forgotten.",
      steps: [
        "On a matter, open the Activity tab and press Log activity to record what happened (a call, a filing, a letter).",
        "In the same popup, choose when to bring the file up again (tomorrow, in 7 days, or a date you pick) and who should be reminded.",
        "Open Bring-up system to see your reminders under Overdue, Today and Upcoming.",
        "Press Complete when it's done, Snooze 7d to push it back a week, or pick another person to hand it over. Partners can view anyone's bring-ups."
      ],
      shots: [
        {"matter-activity.png", "A matter's activity history"},
        {"log-activity.png", "Logging an activity and setting a bring-up"},
        {"diary.png", "Your bring-ups: overdue, today and upcoming"}
      ]
    },
    %{
      id: "calendar",
      title: "Calendar and deadlines",
      intro: "Hearings, mentions, meetings and deadlines for the whole firm.",
      steps: [
        "Open Calendar & deadlines. The top box is the day's cause list, and Next day moves forward a day.",
        "Below it is the firm calendar with everything coming up.",
        "Press New diary event to add a hearing, meeting or deadline. Link it to a matter and assign it to the person handling it."
      ],
      shots: [
        {"calendar.png", "The daily cause list and firm calendar"},
        {"calendar-new-event.png", "Adding a diary event"}
      ]
    },
    %{
      id: "documents",
      title: "Document management",
      intro: "All documents, filed by client, then matter, then category.",
      steps: [
        "Open Document management. On the left, click a client to see their matters, then click a folder.",
        "Use the search box and filters to find a document by its text, title, tags, category or date.",
        "Press Upload documents, choose the client, matter and category, then drop in one or more files and press File documents.",
        "Open a document to preview it. Use Edit details to re-file it, Upload version to add a newer copy (older versions are kept), and Download to save it."
      ],
      shots: [
        {"documents.png", "The document library"},
        {"documents-upload.png", "Uploading documents"},
        {"document-view.png", "Viewing a document and its versions"}
      ]
    },
    %{
      id: "fees",
      title: "Legal fees (finance and billing)",
      intro: "Fee agreements, time, expenses and invoices for each matter.",
      steps: [
        "On a matter, open the Billing tab to see what has been billed, paid and is still outstanding.",
        "Press Fee agreement to record the agreed fee and terms.",
        "Press Add time to record time worked, or Add disbursement for expenses such as filing fees.",
        "Press Create draft invoice to turn unbilled time and expenses into an invoice. Open Legal fees in the menu to see all invoices."
      ],
      shots: [
        {"matter-billing.png", "A matter's billing summary"},
        {"add-time.png", "Recording time"},
        {"billing.png", "All invoices"}
      ]
    },
    %{
      id: "allocation",
      title: "Work allocation (who handles what)",
      intro: "See what each person is working on and move work between people.",
      steps: [
        "Open Work allocation. Each card shows one team member with their matters, open tasks, bring-ups and upcoming events.",
        "A red badge shows how many of that person's items are overdue.",
        "Matters with nobody responsible are listed under Needs an advocate.",
        "Press Reassign next to a matter, or Reassign a matter at the top, choose the new advocate and press Reassign."
      ],
      shots: [
        {"allocation.png", "Team workload"},
        {"reassign.png", "Reassigning a matter"}
      ]
    },
    %{
      id: "intake",
      title: "Intake and compliance",
      intro: "Take on new clients properly and check for conflicts of interest.",
      steps: [
        "Open Intake & compliance and press New client intake to record a prospective client, with their consent.",
        "Use Conflict search to check names against existing clients, opposing parties and opposing counsel. Each check is saved."
      ],
      shots: [{"intake.png", "Intake queue and conflict search"}]
    },
    %{
      id: "team",
      title: "Team access (admins only)",
      intro: "Control who can use the system and what they can see.",
      steps: [
        "Open Team access and press Invite team member. They will get a secure sign-in link by email.",
        "Change a person's role from the list, or untick Active to remove their access."
      ],
      shots: [{"team.png", "Managing the team"}]
    }
  ]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, sections: @sections, page_title: "User manual")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="User manual" eyebrow="How to use the system" />
      <div class="manual-layout">
        <nav id="manual-contents" class="manual-toc" aria-label="Manual contents">
          <p>Contents</p>
          <a :for={s <- @sections} href={"##{s.id}"}>{s.title}</a>
        </nav>
        <div class="manual-body">
          <section :for={s <- @sections} id={s.id} class="manual-section">
            <h2>{s.title}</h2>
            <p class="manual-intro">{s.intro}</p>
            <ol class="manual-steps">
              <li :for={step <- s.steps}>{step}</li>
            </ol>
            <figure :for={{file, caption} <- s.shots} class="manual-shot">
              <img src={~p"/images/manual/#{file}"} alt={caption} loading="lazy" />
              <figcaption>{caption}</figcaption>
            </figure>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
