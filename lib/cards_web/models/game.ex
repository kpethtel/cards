defmodule CardsWeb.Game do
  use GenServer
  require Logger

  @questions [
    "Where do you see yourself in five years?",
    "What's your greatest weakness?",
    "What's your greatest strength?",
    "How would you describe your work style?",
    "What is your spirit animal?",
    "Can you tell us about a time you made a mistake?",
    "Can you tell us about an accomplishment you're proud of?",
    "What do you enjoy most about your work?"
  ]

  @phases ["submission", "voting", "result"]

  def start_link(name: name) do
    Logger.info("received name: #{name}")
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(state) do
    Logger.info("=== INITIALIZING GAME ===")
    state = put_in(state, [:phase_index], 0)
    state = put_in(state, [:users], %{})
    question = Enum.random(@questions)
    state = put_in(state, [:question], question)

    {:ok, state}
  end

  @impl true
  def handle_cast({:set_user, user_id, name}, state) do
    Logger.info("ADDING USER TO STATE: #{name}")
    phase_index = get_in(state, [:phase_index])
    status = if phase_index == 0, do: "pending", else: "waiting"
    # might be worth breaking out gif and index into separate section because the values may change dependent upon game type
    # perhaps call it deck
    state = put_in(state, [:users, user_id], %{name: name, links: [], gif_index: 0, status: status, vote: nil})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_user, user_id}, state) do
    IO.inspect(state, label: "BEFORE DELETE")
    {_old, state} = pop_in(state, [:users, user_id])
    IO.inspect(state, label: "AFTER DELETE")

    {:noreply, state}
  end

  @impl true
  def handle_cast(:reset_round, state) do
    Logger.info("RESETTING ROUND")
    state = put_in(state, [:phase_index], 0)

    # will eventually need to refine this
    question = Enum.random(@questions)
    state = put_in(state, [:question], question)
    users = Enum.filter(state[:users], fn {_user, user_data} -> user_data[:status] != nil end)
    reset_users = Enum.reduce(users, %{}, fn {user, user_data}, acc ->
      new_data = %{name: user_data.name, links: [], gif_index: 0, status: "pending", vote: nil}
      put_in(acc, [user], new_data)
    end)
    state = put_in(state, [:users], reset_users)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_links, socket_id, links}, state) do
    Logger.info("ADDING LINKS TO STATE")
    state = put_in(state, [:users, socket_id, :links], links)
    state = put_in(state, [:users, socket_id, :gif_index], 0)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:shift_index, socket_id, offset}, state) do
    Logger.info("CHANGING INDEX")
    current_index = get_in(state, [:users, socket_id, :gif_index])
    new_index = current_index + offset
    state = put_in(state, [:users, socket_id, :gif_index], new_index)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_status, socket_id}, state) do # perhaps use pattern matching for new status value
    state = put_in(state, [:users, socket_id, :status], "complete")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_vote, user_id, vote_id}, state) do
    state = put_in(state, [:users, user_id, :status], "complete")
    state = put_in(state, [:users, user_id, :vote], vote_id)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_current_gif, socket_id}, _from, state) do
    Logger.info("FETCHING NEW GIF")
    current_image = current_image_for_user(state, socket_id)
    {:reply, current_image, state}
  end

  @impl true
  def handle_call({:get_index, socket_id}, _from, state) do
    Logger.info("FETCHING INDEX")
    current_index = get_in(state, [:users, socket_id, :gif_index])
    {:reply, current_index, state}
  end

  @impl true
  def handle_call(:get_current_question, _from, state) do
    Logger.info("FETCHING question")
    question = get_in(state, [:question])
    {:reply, question, state}
  end

  @impl true
  def handle_call(:get_phase, _from, state) do
    index = get_in(state, [:phase_index])
    phase = Enum.at(@phases, index)

    {:reply, phase, state}
  end

  def handle_call(:phase_complete, _from, state) do
    users = active_users(state)
    index = get_in(state, [:phase_index])
    phase = Enum.at(@phases, index)
    phase_complete = if length(users) > 0 do
      Enum.all?(users, fn({_, user_data}) -> Map.fetch!(user_data, :status) == "complete" end)
    else
      false
    end

    {:reply, phase_complete, state}
  end

  def handle_cast(:increment_phase, state) do
    users = active_users(state)
    reset_users = Enum.reduce(users, %{}, fn {user, user_data}, acc ->
      new_data = %{name: user_data.name, links: user_data.links, gif_index: user_data.gif_index, status: "pending", vote: nil}
      put_in(acc, [user], new_data)
    end)
    state = put_in(state, [:users], reset_users)

    {:noreply, state}
  end

  @imple true
  def handle_call(:get_candidates, _from, state) do
    users = active_users(state)
    links = Enum.map(users, fn {user, user_data} ->
      links = get_in(user_data, [:links])
      index = get_in(user_data, [:gif_index])
      {:ok, link} = Enum.fetch(links, index)
      %{user_id: user, link: link}
    end)
    {:reply, links, state}
  end

  @imple true
  def handle_call(:get_winners, _from, state) do
    # there's gotta be a better way than this sequence
    ranked = state
              |> active_users
              |> Enum.map(fn {_user, user_data} ->
                  get_in(user_data, [:vote])
                end)
              |> Enum.frequencies

    {_, most_votes} = Enum.max_by(ranked, &elem(&1, 1))
    winners = Enum.filter(ranked, fn { _voted_id, vote_count} -> vote_count == most_votes end)
    winning_images = Enum.map(winners, fn { voted_id, _vote_count} -> current_image_for_user(state, voted_id) end)
    {:reply, winning_images, state}
  end

  def add_user(server, user_id, name) do
    Logger.info("ADDING USER")
    GenServer.cast(server, {:set_user, user_id, name})
  end

  def remove_user(server, user_id) do
    Logger.info(user_id, label: "REMOVING USER")
    GenServer.cast(server, {:delete_user, user_id})
  end

  def fetch_question(server) do
    GenServer.call(server, :get_current_question)
  end

  def fetch_current_phase(server) do # rename to get_current_phase or current_pahse
    Logger.info("GET PHASE")
    GenServer.call(server, :get_phase)
  end

  def initialize_gif_deck(server, socket_id, links) do
    Logger.info("ADDING IMAGES")
    GenServer.cast(server, {:set_links, socket_id, links})
  end

  def change_gif_index(server, socket_id, "previous") do
    Logger.info("FETCHING PREVIOUS IMAGE FROM STATE")
    GenServer.cast(server, {:shift_index, socket_id, -1})
  end

  def change_gif_index(server, socket_id, "next") do
    Logger.info("FETCHING NEXT IMAGE FROM STATE")
    GenServer.cast(server, {:shift_index, socket_id, 1})
  end

  def fetch_current_image(server, socket_id) do
    Logger.info("FETCHING CURRENT IMAGE FROM STATE")
    GenServer.call(server, {:get_current_gif, socket_id})
  end

  def submit_answer(server, socket_id, room_topic) do
    Logger.info("SELECTING ANSWER")
    GenServer.cast(server, {:set_status, socket_id})
    complete = GenServer.call(server, :phase_complete)
    Logger.info("PHASE COMPLETE IS: #{complete}")

    if complete == true do
      GenServer.cast(server, :increment_phase)
      # also reset all user statuses
      candidates = GenServer.call(server, :get_candidates)
      CardsWeb.Endpoint.broadcast(room_topic, "start_voting", candidates)
    end
  end

  def cast_vote(server, user_id, vote_id, room_topic) do
    Logger.info("VOTING ON CANDIDATE")
    GenServer.cast(server, {:record_vote, user_id, vote_id})
    complete = GenServer.call(server, :phase_complete)
    Logger.info("PHASE COMPLETE IS: #{complete}")

    if complete == true do
      winners = GenServer.call(server, :get_winners)
      GenServer.cast(server, :increment_phase)
      CardsWeb.Endpoint.broadcast(room_topic, "show_result", winners)
    end
  end

  def start_new_round(server) do
    Logger.info("=== Start new round ===")
    GenServer.cast(server, :reset_round)
  end

  def active_users(state) do
    # filter out nil users, which sometimes occur due to reloaded pages
    users = Enum.filter(state[:users], fn {_user, user_data} -> !(user_data[:status] in [nil, "waiting"]) end)
    IO.inspect(users, label: "=== GOT USERS ===")
    users
  end

  def current_image_for_user(state, user_id) do
    current_index = get_in(state, [:users, user_id, :gif_index])
    links = get_in(state, [:users, user_id, :links])
    {:ok, current_image} = Enum.fetch(links, current_index)
    current_image
  end
end
