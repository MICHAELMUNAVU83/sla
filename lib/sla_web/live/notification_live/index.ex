defmodule SlaWeb.NotificationLive.Index do
  use SlaWeb, :live_view
  alias Sla.Tracker

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    notifications = Tracker.unread_notifications(user_id)
    Tracker.mark_notifications_read(user_id)
    {:ok, stream(socket, :notifications, notifications)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title="Notifications" eyebrow="Recent alerts" /><div
        id="notifications"
        phx-update="stream"
        class="data-list"
      >
        <div id="notifications-empty" class="empty-state hidden only:block">
          You're all caught up.
        </div><article
          :for={{id, notification} <- @streams.notifications}
          id={id}
          class="data-row"
        >
          <div class="file-mark"><.icon name="hero-bell" class="size-5" /></div><div>
            <p class="row-title">{notification.title}</p><p class="row-meta">{notification.body}</p>
          </div>
        </article>
      </div>
    </Layouts.app>
    """
  end
end
