defmodule CardsWeb.PageLive do
  use CardsWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, %{})}
  end

  @impl true
  def handle_event("admit_user", %{"chat" => %{"username" => username}}, socket) do
    {:noreply, push_redirect(socket, to: Routes.room_path(CardsWeb.Endpoint, :index, "default", username: username))}
  end
end
