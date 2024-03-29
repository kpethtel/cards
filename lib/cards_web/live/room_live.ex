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
      CardsWeb.Game.add_user(:default, socket.id, username)
    end

    question = CardsWeb.Game.fetch_question(:default)
    phase = CardsWeb.Game.fetch_current_phase(:default)

    {:ok,
    assign(
      socket,
      room_id: room_id,
      topic: topic,
      username: username,
      message_list: [],
      user_list: [],
      images: [],
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
    links = fetch_gifs(socket.id, search_query)
    links = Enum.shuffle(links)
    CardsWeb.Game.initialize_image_deck(:default, socket.id, links)
    first_url = CardsWeb.Game.fetch_current_image(:default, socket.id)
    {:noreply, assign(socket, images: [first_url])}
  end

  @impl true
  def handle_event("change_image", %{"direction" => direction}, socket) do
    CardsWeb.Game.change_image_index(:default, socket.id, direction)
    new_image = CardsWeb.Game.fetch_current_image(:default, socket.id)
    {:noreply, assign(socket, images: [new_image])}
  end

  @impl true
  def handle_event("select_answer", _value, socket) do
    CardsWeb.Game.submit_answer(:default, socket.id, socket.assigns.topic)

    {:noreply, assign(socket, prompt: "Waiting on voting round")}
  end

  @impl true
  def handle_event("vote_for_winner", %{"selection" => selected_id}, socket) do
    CardsWeb.Game.cast_vote(:default, socket.id, selected_id, socket.assigns.topic)
    image = CardsWeb.Game.fetch_current_image(:default, selected_id)
    {:noreply, assign(socket, images: [image], prompt: "Waiting on other votes")}
  end

  @impl true
  def handle_info(%{event: "start_voting", payload: candidates}, socket) do
    {:noreply, assign(socket, prompt: "Vote on the winner", phase: "voting", images: candidates)}
  end

  @impl true
  def handle_info(%{event: "show_result", payload: winners}, socket) do
    Process.send_after(self(), :start_next_round, 3_000)

    {:noreply, assign(socket, prompt: "Behold, the winner!", phase: "result", images: winners)}
  end

  @impl true
  def handle_info(:start_next_round, socket) do
    # is it possible to do this in the previous step to avoid duplicate data fetching
    CardsWeb.Game.start_new_round(:default)
    next_phase = CardsWeb.Game.fetch_current_phase(:default)
    question = CardsWeb.Game.fetch_question(:default)
    prompt = "Search for an appropriate answer to the question"

    {:noreply, assign(socket, phase: next_phase, prompt: prompt, question: question, images: [])}
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

  def terminate(_reason, socket) do
    CardsWeb.Game.remove_user(:default, socket.id)

    :ok
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

  def display_images(assigns = %{phase: phase, images: images}) do
    area_class = if Enum.count(images) > 1, do: "multi-image-area", else: "image-area"

    ~H"""
      <div id={area_class}>
        <%= case phase do %>
          <% "voting" -> %>
            <%= for image <- images do %>
              <img src={get_in(image, [:link])} phx-click="vote_for_winner" phx-value-selection={get_in(image, [:user_id])}>
            <% end %>
          <% _ -> %>
            <%= for image <- images do %>
              <img src={get_in(image, [:link])} phx-click="vote_for_winner"}>
            <% end %>
        <% end %>
      </div>
    """
  end

  def display_controls(assigns = %{phase: phase, images: images}) do
    if phase == "submission" && Enum.count(images) > 0 do
      ~H"""
        <div id="image-navigation-controls">
          <div class="button-area">
            <button phx-click="change_image" phx-value-direction="previous">Previous</button>
          </div>
          <div class="button-area">
            <button phx-click="select_answer">Select</button>
          </div>
          <div class="button-area">
            <button phx-click="change_image" phx-value-direction="next">Next</button>
          </div>
        </div>
      """
    end
  end

  # this should not be in the room
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
