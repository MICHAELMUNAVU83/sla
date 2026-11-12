defmodule SlaWeb.DocumentLive.Index do
  use SlaWeb, :live_view
  alias Sla.{Accounts, Clients, Documents, Matters, Storage}

  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user

    filters = %{
      "search" => "",
      "client" => params["client_id"] || "",
      "matter" => params["matter_id"] || "",
      "category" => params["category_id"] || "",
      "uploader" => "",
      "from" => "",
      "to" => ""
    }

    socket =
      assign(socket,
        filters: filters,
        clients: Clients.list_clients_with_matters(),
        matters: Matters.list_matters_for_user(user),
        categories: Documents.list_all_categories(),
        users: Accounts.list_users(),
        upload_form: upload_form(filters),
        category_form:
          to_form(%{"name" => "", "slug" => "", "practice_area" => "", "position" => "100"},
            as: :category
          ),
        admin?: user.role in ["partner", "admin"]
      )

    {:ok,
     socket
     |> configure_upload(:documents, max_entries: 10)
     |> stream(:documents, Documents.list_documents(user, filters))}
  end

  def handle_event("filter", params, socket) do
    filters = Map.take(params, ~w(search client matter category uploader from to))

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> stream(:documents, Documents.list_documents(socket.assigns.current_scope.user, filters),
       reset: true
     )}
  end

  def handle_event("validate-upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-upload", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :documents, ref)}

  def handle_event(
        "create-category",
        %{"category" => attrs},
        %{assigns: %{admin?: true}} = socket
      ) do
    attrs = if attrs["practice_area"] == "", do: Map.put(attrs, "practice_area", nil), else: attrs

    case Documents.create_category(attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:categories, Documents.list_all_categories())
         |> assign(
           :category_form,
           to_form(%{"name" => "", "slug" => "", "practice_area" => "", "position" => "100"},
             as: :category
           )
         )
         |> put_flash(:info, "Document category created.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :category_form, to_form(changeset, as: :category))}
    end
  end

  def handle_event("toggle-category", %{"id" => id}, %{assigns: %{admin?: true}} = socket) do
    category = Documents.get_category!(id)
    {:ok, _} = Documents.update_category(category, %{active: !category.active})
    {:noreply, assign(socket, :categories, Documents.list_all_categories())}
  end

  def handle_event("save-documents", %{"document" => attrs}, socket) do
    uploads =
      consume_uploaded_entries(socket, :documents, fn meta, entry ->
        {:ok, upload_metadata(meta, entry)}
      end)

    results =
      Enum.map(uploads, fn upload ->
        title =
          if length(uploads) == 1 && attrs["title"] not in [nil, ""],
            do: attrs["title"],
            else: Path.rootname(upload.filename)

        Documents.create_document(
          socket.assigns.current_scope.user,
          Map.merge(attrs, %{"title" => title}),
          upload
        )
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        {:noreply,
         socket
         |> assign(:upload_form, upload_form(socket.assigns.filters))
         |> stream(
           :documents,
           Documents.list_documents(socket.assigns.current_scope.user, socket.assigns.filters),
           reset: true
         )
         |> close_modal("upload-modal")
         |> put_flash(:info, "#{length(results)} document(s) uploaded.")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Upload could not be saved: #{inspect(changeset.errors)}")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Documents" eyebrow="Client → matter → category">
        <:actions>
          <button
            :if={@admin?}
            id="open-category-settings"
            type="button"
            phx-click={show_modal("category-modal")}
            class="btn-secondary"
          ><.icon name="hero-tag" class="size-4" /> Categories</button>
          <button
            id="open-upload"
            type="button"
            phx-click={show_modal("upload-modal")}
            class="btn-primary"
          ><.icon name="hero-arrow-up-tray" class="size-4" /> Upload documents</button>
        </:actions>
      </.page_header>
      <div class="document-layout">
        <aside class="folder-tree">
          <h2>Folders</h2>
          <.link
            id="folder-all"
            navigate={~p"/documents"}
            class={[no_folder?(@filters) && "folder-active"]}
          ><.icon name="hero-squares-2x2" class="size-4" /> All documents</.link>
          <details
            :for={client <- @clients}
            id={"folder-client-#{client.id}"}
            class="folder-client"
            open={client_open?(@filters, client)}
          >
            <summary><.icon name="hero-user" class="size-4" /> {client.name}</summary>
            <.link
              navigate={~p"/documents?client_id=#{client.id}"}
              class={[
                @filters["client"] == to_string(client.id) && @filters["matter"] == "" &&
                  "folder-active"
              ]}
            >General / Client-level</.link>
            <.link
              :for={matter <- client.matters}
              navigate={~p"/documents?matter_id=#{matter.id}"}
              class={[@filters["matter"] == to_string(matter.id) && "folder-active"]}
            >{matter.file_number}</.link>
          </details>
        </aside><div class="document-main">
          <.form
            for={to_form(@filters)}
            id="document-filters"
            phx-change="filter"
            class="document-filters"
          >
            <.input
              field={to_form(@filters)["search"]}
              type="search"
              placeholder="Search document text, title or tags"
              phx-debounce="300"
            /><.input
              field={to_form(@filters)["client"]}
              type="select"
              options={[{"All clients", ""} | Enum.map(@clients, &{&1.name, &1.id})]}
            /><.input
              field={to_form(@filters)["matter"]}
              type="select"
              options={[
                {"General and all matters", ""}
                | Enum.map(@matters, &{"#{&1.file_number} — #{&1.title}", &1.id})
              ]}
            /><.input
              field={to_form(@filters)["category"]}
              type="select"
              options={[{"All categories", ""} | Enum.map(@categories, &{&1.name, &1.id})]}
            /><.input
              field={to_form(@filters)["uploader"]}
              type="select"
              options={[{"All uploaders", ""} | Enum.map(@users, &{&1.name || &1.email, &1.id})]}
            /><.input field={to_form(@filters)["from"]} type="date" /><.input
              field={to_form(@filters)["to"]}
              type="date"
            />
          </.form>

          <div id="documents" phx-update="stream" class="document-grid">
            <div id="documents-empty" class="empty-state hidden only:block">
              No documents match this folder.
            </div><.link
              :for={{id, document} <- @streams.documents}
              id={id}
              navigate={~p"/documents/#{document}"}
              class="document-card"
            ><div class="document-icon">
              <.icon name={file_icon(document.current_version.content_type)} class="size-6" />
            </div><div>
              <h3>{document.title}</h3><p>{document.current_version.filename}</p><span>{document.category.name} · v{document.current_version.version_no}</span>
            </div></.link>
          </div>
        </div>
      </div>
      <.modal
        id="upload-modal"
        title="Upload documents"
        subtitle="File one or more documents to a client or matter"
        size="lg"
      >
        <.form
          for={@upload_form}
          id="document-upload-form"
          phx-change="validate-upload"
          phx-submit="save-documents"
          class="modal-form"
        >
          <div class="form-grid">
            <.input
              field={@upload_form[:client_id]}
              type="select"
              label="Client"
              options={Enum.map(@clients, &{&1.name, &1.id})}
              prompt="Select client"
            /><.input
              field={@upload_form[:matter_id]}
              type="select"
              label="Matter (optional)"
              options={Enum.map(@matters, &{"#{&1.file_number} — #{&1.title}", &1.id})}
              prompt="General / Client-level"
            />
          </div><div class="form-grid">
            <.input
              field={@upload_form[:category_id]}
              type="select"
              label="Category"
              options={Enum.map(@categories, &{&1.name, &1.id})}
              prompt="Select category"
            /><.input field={@upload_form[:title]} label="Title (single file only)" />
          </div><.input
            field={@upload_form[:tags]}
            label="Tags"
            placeholder="contract, signed, urgent"
          /><label
            id="document-drop-zone"
            class="drop-zone"
            phx-drop-target={@uploads.documents.ref}
          ><.icon name="hero-cloud-arrow-up" class="size-8" /><strong>Drop files here or choose files</strong><span>PDF, images and Office files · up to 50 MB each</span><.live_file_input upload={
            @uploads.documents
          } /></label><div
            :for={entry <- @uploads.documents.entries}
            id={"upload-#{entry.ref}"}
            class="upload-entry"
          >
            <span>{entry.client_name}</span><progress value={entry.progress} max="100">{entry.progress}%</progress><button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
            >×</button>
          </div><p :for={err <- upload_errors(@uploads.documents)} class="upload-error">
            {error_to_string(err)}
          </p><div class="form-actions">
            <button type="button" class="btn-secondary" phx-click={hide_modal("upload-modal")}>Cancel</button>
            <.button id="save-documents" class="btn-primary" phx-disable-with="Filing…">File documents</.button>
          </div>
        </.form>
      </.modal>
      <.modal
        :if={@admin?}
        id="category-modal"
        title="Document categories"
        subtitle="Click × on a category to deactivate it"
      >
        <div class="category-pills">
          <span :for={category <- @categories}>{category.name}<button
            phx-click="toggle-category"
            phx-value-id={category.id}
            aria-label={"Deactivate #{category.name}"}
          >×</button></span>
        </div>
        <div class="mt-5">
          <.form
            for={@category_form}
            id="category-form"
            phx-submit="create-category"
            class="modal-form"
          >
            <.input field={@category_form[:name]} label="Name" /><.input
              field={@category_form[:slug]}
              label="Slug"
            /><.input
              field={@category_form[:practice_area]}
              type="select"
              label="Practice area"
              options={[
                {"All practice areas", ""}
                | Enum.map(Sla.Matters.Matter.practice_areas(), &{humanize(&1), &1})
              ]}
            /><.input field={@category_form[:position]} type="number" label="Sort position" /><div class="form-actions">
              <.button id="save-category" class="btn-primary" phx-disable-with="Adding…">Add category</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp configure_upload(socket, name, opts) do
    base =
      [
        accept: ~w(.pdf .png .jpg .jpeg .webp .doc .docx .xls .xlsx .txt),
        max_file_size: 50_000_000,
        auto_upload: true
      ] ++ opts

    if Storage.direct_upload?(),
      do: allow_upload(socket, name, Keyword.put(base, :external, &Storage.presign_upload/2)),
      else: allow_upload(socket, name, base)
  end

  defp upload_metadata(%{path: path}, entry), do: Documents.upload_from_path(path, entry)
  defp upload_metadata(meta, entry), do: Documents.external_upload(meta, entry)

  defp upload_form(filters),
    do:
      to_form(
        %{
          "client_id" => filters["client"],
          "matter_id" => filters["matter"],
          "category_id" => "",
          "title" => "",
          "tags" => ""
        },
        as: :document
      )

  defp no_folder?(filters), do: filters["client"] in [nil, ""] and filters["matter"] in [nil, ""]

  defp client_open?(filters, client) do
    filters["client"] == to_string(client.id) or
      Enum.any?(client.matters, &(filters["matter"] == to_string(&1.id)))
  end

  defp file_icon(type) when type in ["application/pdf"], do: "hero-document-text"
  defp file_icon("image/" <> _), do: "hero-photo"
  defp file_icon(_), do: "hero-document"
  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type is not accepted"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(error), do: inspect(error)

  defp humanize(value),
    do:
      value
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)
end
