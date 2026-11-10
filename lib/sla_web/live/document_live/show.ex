defmodule SlaWeb.DocumentLive.Show do
  use SlaWeb, :live_view
  alias Sla.{Documents, Matters, Storage}

  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user
    document = Documents.get_document!(user, id)

    {:ok,
     socket
     |> assign(
       document: document,
       edit_form: edit_form(document),
       categories: Documents.list_categories(document.matter && document.matter.practice_area),
       matters: Matters.list_matters_for_user(user, %{"client" => document.client_id})
     )
     |> configure_version_upload()}
  end

  def handle_event("validate-version", _, socket), do: {:noreply, socket}

  def handle_event("cancel-version", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :version, ref)}

  def handle_event("save-version", _, socket) do
    [upload] =
      consume_uploaded_entries(socket, :version, fn meta, entry ->
        {:ok, upload_metadata(meta, entry)}
      end)

    {:ok, _} =
      Documents.add_version(socket.assigns.current_scope.user, socket.assigns.document, upload)

    {:noreply,
     socket
     |> assign(
       :document,
       Documents.get_document!(socket.assigns.current_scope.user, socket.assigns.document.id)
     )
     |> put_flash(:info, "New version uploaded.")}
  end

  def handle_event("update-document", %{"document" => attrs}, socket) do
    case Documents.update_document(
           socket.assigns.current_scope.user,
           socket.assigns.document,
           attrs
         ) do
      {:ok, document} ->
        {:noreply,
         socket
         |> assign(
           document: Documents.get_document!(socket.assigns.current_scope.user, document.id),
           edit_form: edit_form(document)
         )
         |> put_flash(:info, "Document filed successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset))}
    end
  end

  def handle_event("restore", %{"version" => version_id}, socket) do
    {:ok, _} =
      Documents.restore_version(
        socket.assigns.current_scope.user,
        socket.assigns.document,
        version_id
      )

    {:noreply,
     socket
     |> assign(
       :document,
       Documents.get_document!(socket.assigns.current_scope.user, socket.assigns.document.id)
     )
     |> put_flash(:info, "Version restored.")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header
        title={@document.title}
        eyebrow={(@document.matter && @document.matter.file_number) || "General / Client-level"}
      >
        <:actions>
          <.link
            id="download-document"
            href={~p"/documents/#{@document}/download"}
            class="btn-primary"
          ><.icon name="hero-arrow-down-tray" class="size-4" /> Download</.link>
        </:actions>
      </.page_header><div class="document-show-grid">
        <section class="preview-card">
          <%= if previewable?(@document.current_version.content_type) do %>
            <iframe
              :if={@document.current_version.content_type == "application/pdf"}
              id="document-preview"
              src={~p"/documents/#{@document}/preview"}
            ></iframe><img
              :if={String.starts_with?(@document.current_version.content_type, "image/")}
              id="document-preview"
              src={~p"/documents/#{@document}/preview"}
              alt={@document.title}
            />
          <% else %>
            <div class="empty-state">
              <.icon name="hero-document" class="size-12" /><p>
                Preview is not available for this file type.
              </p>
            </div>
          <% end %>
        </section><aside class="document-inspector">
          <.form
            for={@edit_form}
            id="document-metadata-form"
            phx-submit="update-document"
            class="form-card"
          >
            <.input field={@edit_form[:title]} label="Title" /><.input
              field={@edit_form[:client_id]}
              type="hidden"
            /><.input
              field={@edit_form[:matter_id]}
              type="select"
              label="Folder / matter"
              options={Enum.map(@matters, &{"#{&1.file_number} — #{&1.title}", &1.id})}
              prompt="General / Client-level"
            /><.input
              field={@edit_form[:category_id]}
              type="select"
              label="Category"
              options={Enum.map(@categories, &{&1.name, &1.id})}
            /><.input field={@edit_form[:tags]} label="Tags" /><.button class="btn-secondary">Save filing details</.button>
          </.form><.form
            for={to_form(%{}, as: :version)}
            id="version-upload-form"
            phx-change="validate-version"
            phx-submit="save-version"
            class="form-card"
          >
            <h2 class="section-title">Upload new version</h2><.live_file_input upload={
              @uploads.version
            } /><div :for={entry <- @uploads.version.entries} class="upload-entry">
              <span>{entry.client_name}</span><progress value={entry.progress} max="100">{entry.progress}%</progress><button
                type="button"
                phx-click="cancel-version"
                phx-value-ref={entry.ref}
              >×</button>
            </div><.button id="save-version" class="btn-primary">Add version</.button>
          </.form><div id="version-history" class="version-list">
            <h2>Version history</h2><article
              :for={version <- @document.versions}
              id={"version-#{version.id}"}
            >
              <div>
                <strong>Version {version.version_no}</strong><span>{version.filename} · {format_bytes(
                  version.size
                )}</span>
              </div><span :if={version.id == @document.current_version_id} class="status-pill">Current</span><button
                :if={version.id != @document.current_version_id}
                phx-click="restore"
                phx-value-version={version.id}
                class="mini-action"
              >Restore</button>
            </article>
          </div>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  defp configure_version_upload(socket) do
    opts = [
      accept: ~w(.pdf .png .jpg .jpeg .webp .doc .docx .xls .xlsx .txt),
      max_entries: 1,
      max_file_size: 50_000_000,
      auto_upload: true
    ]

    if Storage.direct_upload?(),
      do: allow_upload(socket, :version, Keyword.put(opts, :external, &Storage.presign_upload/2)),
      else: allow_upload(socket, :version, opts)
  end

  defp upload_metadata(%{path: path}, entry), do: Documents.upload_from_path(path, entry)
  defp upload_metadata(meta, entry), do: Documents.external_upload(meta, entry)

  defp edit_form(document),
    do:
      to_form(
        %{
          "title" => document.title,
          "client_id" => document.client_id,
          "matter_id" => document.matter_id,
          "category_id" => document.category_id,
          "tags" => Enum.join(document.tags, ", ")
        },
        as: :document
      )

  defp previewable?("application/pdf"), do: true
  defp previewable?("image/" <> _), do: true
  defp previewable?(_), do: false
  defp format_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
