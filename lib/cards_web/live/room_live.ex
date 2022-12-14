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

    question = CardsWeb.Game.get_question(:default)
    phase = CardsWeb.Game.get_phase(:default)

    {:ok,
    assign(
      socket,
      room_id: room_id,
      topic: topic,
      username: username,
      message_list: [],
      user_list: [],
      image: nil,
      next_button_visible: false,
      previous_button_visible: false,
      question: question,
      phase: phase,
      prompt: "Search for an appropriate answer to the question",
      temporary_assigns: [message_list: []]
    )}
  end

  @impl true
  def handle_event("submit_chat_message", %{"text_input" => %{"message" => message_input}}, socket) do
    message_data = %{uuid: UUID.uuid4(), content: message_input, username: socket.assigns.username}
    CardsWeb.Endpoint.broadcast(socket.assigns.topic, "add_new_message", message_data)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_search_query", %{"text_input" => %{"message" => search_query}}, socket) do
    username = socket.assigns.username
    links = fetch_gifs(username, search_query)
    links = Enum.shuffle(links)
    CardsWeb.Game.initialize_gif_deck(:default, username, links)
    first_url = CardsWeb.Game.fetch_current_image(:default, username)
    {:noreply, assign(socket, image: first_url, previous_button_visible: false, next_button_visible: true)}
  end

  @impl true
  def handle_event("change_image", %{"direction" => direction}, socket) do
    username = socket.assigns.username
    CardsWeb.Game.change_gif_index(:default, username, direction)
    new_gif = CardsWeb.Game.fetch_current_image(:default, username)
    previous_button_visible = CardsWeb.Game.previous_gif_exists?(:default, username)
    {:noreply, assign(socket, image: new_gif, previous_button_visible: previous_button_visible)}
  end

  @impl true
  def handle_event("select_answer", _value, socket) do
    username = socket.assigns.username
    CardsWeb.Game.select_answer(:default, username)
    {:noreply, assign(socket, previous_button_visible: false, next_button_visible: false, prompt: "Waiting on voting round")}
  end

  @impl true
  def handle_info(%{event: "add_new_message", payload: message_data}, socket) do
    {:noreply, assign(socket, message_list: [message_data])}
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

    {:noreply, assign(socket, message_list: join_messages ++ leave_messages, user_list: user_list)}
  end

  def display_message(assigns = %{type: :system, uuid: uuid, content: message}) do
    ~H"""
    <li id={uuid}><em><%= message %></em></li>
    """
  end

  def display_message(assigns = %{uuid: uuid, content: message, username: username}) do
    ~H"""
    <li id={uuid}><strong> <%= username %> </strong>: <%= message %></li>
    """
  end

  def fetch_gifs(username, search_term) do
    search_term = URI.encode(search_term)
    giphy_base_url = Application.get_env(:cards, :base_url)
    giphy_api_key = Application.get_env(:cards, :api_key)
    url = giphy_base_url <> "?" <> "api_key=" <> giphy_api_key <> "&q=" <> search_term <> "&limit=10"
    response = HTTPoison.get!(url)
    decoded = Poison.decode!(response.body)
    data = decoded["data"]
    Enum.map(data, fn x -> get_in(x, ["images", "original", "url"]) end)
  end
end
