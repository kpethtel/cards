defmodule CardsWeb.PageLive do
  use CardsWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", results: %{})}
  end

  @impl true
  def handle_event("admit_user", %{"chat" => %{"username" => username}}, socket) do
    Logger.info(username)
    {:noreply, push_redirect(socket, to: "/" <> "default" <> "?username=#{username}")}
  end
end
