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
    "Can you tell us about an accomplishement you're proud of?",
    "What do you enjoy most about your work?"
  ]

  def start_link(name: name) do
    Logger.info("received name: #{name}")
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(state) do
    Logger.info("=== INITIALIZING GAME ===")
    state = put_in(state, [:phase], "waiting")
    state = put_in(state, [:users], %{})
    question = Enum.random(@questions)
    state = put_in(state, [:question], question)

    {:ok, state}
  end

  @impl true
  def handle_cast({:add, user_id, name}, state) do
    Logger.info("ADDING USER TO STATE")
    Logger.info("name #{name}")
    IO.inspect(state, label: "ADD USER STATE")

    # naive
    state = put_in(state, [:phase], "submission")
    state = put_in(state, [:users, user_id], %{name: name, links: [], gif_index: 0, status: "waiting", vote: nil})
    Logger.info("STATE")
    Logger.info(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:load_gif_links, socket_id, links}, state) do
    Logger.info("ADDING LINKS TO STATE")
    state = put_in(state, [:users, socket_id, :links], links)
    state = put_in(state, [:users, socket_id, :gif_index], 0)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:change_current_gif_index, socket_id, offset}, state) do
    Logger.info("CHANGING INDEX")
    current_index = get_in(state, [:users, socket_id, :gif_index])
    new_index = current_index + offset
    state = put_in(state, [:users, socket_id, :gif_index], new_index)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:submit_answer, socket_id}, state) do
    state = put_in(state, [:users, socket_id, :status], "submitted")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_vote, user_id, vote_id}, state) do
    state = put_in(state, [:users, user_id, :status], "voted")
    state = put_in(state, [:users, user_id, :vote], vote_id)
    {:noreply, state}
  end

  @impl true
  def handle_call({:fetch_current_gif, socket_id}, _from, state) do
    Logger.info("FETCHING NEW GIF")
    current_image = current_image_for_user(state, socket_id)
    {:reply, current_image, state}
  end

  @impl true
  def handle_call({:fetch_current_index, socket_id}, _from, state) do
    Logger.info("FETCHING INDEX")
    current_index = get_in(state, [:users, socket_id, :gif_index])
    {:reply, current_index, state}
  end

  @impl true
  def handle_call(:fetch_current_question, _from, state) do
    Logger.info("FETCHING question")
    question = get_in(state, [:question])
    {:reply, question, state}
  end

  @impl true
  def handle_call(:fetch_current_phase, _from, state) do
    Logger.info("FETCHING PHASE")
    IO.inspect(state, label: "=== FETCHING CURRENT PHASE ===")
    users = active_users(state)
    phase = get_in(state, [:phase])

    if length(users) > 0 do
      new_phase = case phase do
        "submission" ->
          all_submitted = Enum.all?(users, fn({_, user_data}) -> Map.fetch!(user_data, :status) == "submitted" end)
          Logger.info("all submitted is #{all_submitted}")
          if all_submitted, do: "voting", else: "submission"
        "voting" ->
          all_voted = Enum.all?(users, fn({_, user_data}) -> Map.fetch!(user_data, :status) == "voted" end)
          Logger.info("all voted is #{all_voted}")
          if all_voted, do: "result", else: "voting"
        "result" ->
          "result"
        "waiting" ->
          "waiting"
      end

      state = put_in(state, [:phase], new_phase)

      {:reply, new_phase, state}
    else
      {:reply, phase, state}
    end
  end

  @imple true
  def handle_call(:current_candidates, _from, state) do
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
  def handle_call(:winner, _from, state) do
    users = active_users(state)
    votes = Enum.map(users, fn {_user, user_data} ->
      get_in(user_data, [:vote])
    end)
    # this is a naive implementation; return to it later
    winning_user_id = Enum.max(votes)
    current_image = current_image_for_user(state, winning_user_id)
    {:reply, current_image, state}
  end

  def add_user(server, user_id, name) do
    Logger.info("ADDING USER")
    GenServer.cast(server, {:add, user_id, name})
  end

  def get_question(server) do
    GenServer.call(server, :fetch_current_question)
  end

  def get_phase(server) do
    Logger.info("GET PHASE")
    GenServer.call(server, :fetch_current_phase)
  end

  def initialize_gif_deck(server, socket_id, links) do
    Logger.info("ADDING IMAGES")
    GenServer.cast(server, {:load_gif_links, socket_id, links})
  end

  def change_gif_index(server, socket_id, "previous") do
    Logger.info("FETCHING PREVIOUS IMAGE FROM STATE")
    GenServer.cast(server, {:change_current_gif_index, socket_id, -1})
  end

  def change_gif_index(server, socket_id, "next") do
    Logger.info("FETCHING NEXT IMAGE FROM STATE")
    GenServer.cast(server, {:change_current_gif_index, socket_id, 1})
  end

  def fetch_current_image(server, socket_id) do
    Logger.info("FETCHING CURRENT IMAGE FROM STATE")
    GenServer.call(server, {:fetch_current_gif, socket_id})
  end

  def previous_gif_exists?(server, socket_id) do
    Logger.info("DOES A PREVIOUS GIF EXIST?")
    current_index = GenServer.call(server, {:fetch_current_index, socket_id})
    IO.inspect(current_index)
    current_index > 0
  end

  def submit_answer(server, socket_id) do
    Logger.info("SELECTING ANSWER")
    GenServer.cast(server, {:submit_answer, socket_id})
  end

  def fetch_candidates(server) do
    Logger.info("FETCHING CANDIDATES")
    GenServer.call(server, :current_candidates)
  end

  def vote(server, user_id, vote_id) do
    Logger.info("VOTING ON CANDIDATE")
    GenServer.cast(server, {:record_vote, user_id, vote_id})
  end

  def fetch_winner(server) do
    Logger.info("GETTING WINNER")
    winning_player = GenServer.call(server, :winner)
  end

  def active_users(state) do
    users = Enum.filter(state[:users], fn {_user, user_data} -> user_data[:status] != nil end)
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
