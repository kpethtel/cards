defmodule CardsWeb.RoomLive do
  use CardsWeb, :live_view
  require Logger
  require HTTPoison
  require Poison

  @impl true
  def mount(%{"id" => room_id, "username" => username}, _session, socket) do
    topic = "room:" <> room_id

    if connected?(socket) do
      CardsWeb.Endpoint.subscribe(topic)
      CardsWeb.Presence.track(self(), topic, username, %{})
    end

    {:ok,
    assign(
      socket,
      room_id: room_id,
      topic: topic,
      username: username,
      message: "",
      messages: [],
      user_list: [],
      image: "",
      temporary_assigns: [messages: [], image: ""]
    )}
  end

  @impl true
  def handle_event("submit_message", %{"chat" => %{"message" => message}}, socket) do
    message = %{uuid: UUID.uuid4(), content: message, username: socket.assigns.username}
    CardsWeb.Endpoint.broadcast(socket.assigns.topic, "new-message", message)
    {:noreply, assign(socket, message: "")}
  end

  @impl true
  def handle_event("form_update", %{"chat" => %{"message" => message}}, socket) do
    Logger.info(message: message)
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_info(%{event: "new-message", payload: message}, socket) do
    Logger.info("HANDLING INFO")
    Logger.info(payload: message)
    image = fetch_image(message[:content])
    {:noreply, assign(socket, messages: [message], image: image)}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    Logger.info("JOINED")
    Logger.info(joins)
    join_messages =
      joins
      |> Map.keys()
      |> Enum.map(fn username -> %{type: :system, uuid: UUID.uuid4(), content: "#{username} joined"} end)

    leave_messages =
      leaves
      |> Map.keys()
      |> Enum.map(fn username -> %{type: :system, uuid: UUID.uuid4(), content: "#{username} left"} end)

    user_list = CardsWeb.Presence.list(socket.assigns.topic)
    |> Map.keys()

    {:noreply, assign(socket, messages: join_messages ++ leave_messages, user_list: user_list)}
  end

  def display_message(assigns = %{type: :system, uuid: uuid, content: content}) do
    Logger.info("DISPLAY SYSTEM " <> uuid)
    ~H"""
    <p id={uuid}><em><%= content %></em></p>
    """
  end

  def display_message(assigns = %{uuid: uuid, content: content, username: username}) do
    Logger.info("DISPLAY CONTENT " <> uuid)
    ~H"""
    <p id={uuid}><strong> <%= username %> </strong>: <%= content %></p>
    """
  end

  def fetch_image(message) do
    encoded_message = URI.encode(message)
    giphy_base_url = Application.get_env(:cards, :base_url)
    giphy_api_key = Application.get_env(:cards, :api_key)
    Logger.info(giphy_base_url)
    url = giphy_base_url <> "?" <> "api_key=" <> giphy_api_key <> "&q=" <> encoded_message
    response = HTTPoison.get!(url)
    Logger.info(response)
    decoded = Poison.decode!(response.body)
    Logger.info("DECODED")
    data = decoded["data"]
    first_url = Enum.at(data, 0)["images"]["original"]["url"]
    Logger.info(first_url)
    first_url
  end
end
