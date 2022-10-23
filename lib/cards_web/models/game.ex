defmodule CardsWeb.Game do
  use GenServer
  require Logger

  @questions [
    "Where do you see yourself in five years?"
  ]

  def start_link(name: name) do
    Logger.info("received name: #{name}")
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add, name}, state) do
    Logger.info("ADDING USER TO STATE")
    Logger.info("name #{name}")

    state = Map.put(state, name, %{links: [], gif_index: 0})
    Logger.info("STATE")
    Logger.info(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:load_gif_links, username, links}, state) do
    Logger.info("ADDING LINKS TO STATE")
    state = put_in(state, [username, :links], links)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:change_current_gif_index, username, offset}, state) do
    Logger.info("CHANGING INDEX")
    current_index = get_in(state, [username, :gif_index])
    new_index = current_index + offset
    state = put_in(state, [username, :gif_index], new_index)
    {:noreply, state}
  end

  @impl true
  def handle_call({:fetch_current_gif, username}, _from, state) do
    Logger.info("FETCHING NEW GIF")
    current_index = get_in(state, [username, :gif_index])
    links = get_in(state, [username, :links])
    current_image = Enum.fetch(links, current_index)
    {:reply, current_image, state}
  end

  @impl true
  def handle_call({:fetch_current_index, username}, _from, state) do
    Logger.info("FETCHING INDEX")
    current_index = get_in(state, [username, :gif_index])
    {:reply, current_index, state}
  end

  def add_user(server, name) do
    Logger.info("ADDING USER")
    GenServer.cast(server, {:add, name})
  end

  def get_question(server) do
    Enum.random(@questions)
  end

  def initialize_gif_deck(server, username, links) do
    Logger.info("ADDING IMAGES")
    GenServer.cast(server, {:load_gif_links, username, links})
  end

  def change_gif_index(server, username, "previous") do
    Logger.info("FETCHING PREVIOUS IMAGE FROM STATE")
    GenServer.cast(server, {:change_current_gif_index, username, -1})
  end

  def change_gif_index(server, username, "next") do
    Logger.info("FETCHING NEXT IMAGE FROM STATE")
    GenServer.cast(server, {:change_current_gif_index, username, 1})
  end

  def fetch_current_image(server, username) do
    Logger.info("FETCHING CURRENT IMAGE FROM STATE")
    {:ok, current_image} = GenServer.call(server, {:fetch_current_gif, username})
    current_image
  end

  def previous_gif_exists?(server, username) do
    Logger.info("DOES A PREVIOUS GIF EXIST?")
    current_index = GenServer.call(server, {:fetch_current_index, username})
    IO.inspect(current_index)
    current_index > 0
  end
end
