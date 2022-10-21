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
      CardsWeb.Game.add_user(:default, username)
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
  def handle_event("submit_message", %{"chat" => %{"message" => incoming_message}}, socket) do
    username = socket.assigns.username
    outgoing_message = %{uuid: UUID.uuid4(), content: incoming_message, username: username}
    CardsWeb.Endpoint.broadcast(socket.assigns.topic, "new_message", outgoing_message)
    links = fetch_gifs(username, incoming_message)
    links = Enum.shuffle(links)
    CardsWeb.Game.initialize_gif_deck(:default, username, links)
    first_url = CardsWeb.Game.fetch_current_image(:default, username)
    {:noreply, assign(socket, message: "", image: first_url)}
  end

  @impl true
  def handle_event("form_update", %{"chat" => %{"message" => message}}, socket) do
    Logger.info(message: message)
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_info(%{event: "new_message", payload: message}, socket) do
    Logger.info("HANDLING INFO")
    Logger.info(payload: message)
    {:noreply, assign(socket, messages: [message])}
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

  @impl true
  def handle_event("change_image", %{"direction" => "previous"}, socket) do
    Logger.info("PREVIOUS")
    username = socket.assigns.username
    CardsWeb.Game.change_gif_index(:default, username, "previous")
    new_gif = CardsWeb.Game.fetch_current_image(:default, username)
    {:noreply, assign(socket, image: new_gif)}
  end

  @impl true
  def handle_event("change_image", %{"direction" => "next"}, socket) do
    Logger.info("NEXT")
    username = socket.assigns.username
    CardsWeb.Game.change_gif_index(:default, username, "next")
    new_gif = CardsWeb.Game.fetch_current_image(:default, username)
    {:noreply, assign(socket, image: new_gif)}
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

  def fetch_gifs(username, message) do
    encoded_message = URI.encode(message)
    giphy_base_url = Application.get_env(:cards, :base_url)
    giphy_api_key = Application.get_env(:cards, :api_key)
    url = giphy_base_url <> "?" <> "api_key=" <> giphy_api_key <> "&q=" <> encoded_message <> "&limit=10"
    response = HTTPoison.get!(url)
    decoded = Poison.decode!(response.body)
    data = decoded["data"]
    Enum.map(data, fn x -> get_in(x, ["images", "original", "url"]) end)
  end
end
