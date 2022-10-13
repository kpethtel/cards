defmodule CardsWeb.Game do
  use GenServer
  require Logger

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

    state = Map.put(state, name, %{links: []})
    Logger.info("STATE")
    Logger.info(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_links, username, links}, state) do
    Logger.info("ADDING LINKS TO STATE")
    links_list = get_in(state, [username, :links])
    links_list = [links | links_list]
    state = put_in(state, [username, :links], links_list)
    Logger.info("STATE")
    Logger.info(state)
    {:noreply, state}
  end

  def add_user(server, name) do
    Logger.info("ADDING USER")
    GenServer.cast(server, {:add, name})
  end

  def add_image_links(server, username, links) do
    Logger.info("ADDING IMAGES")
    GenServer.cast(server, {:add_links, username, links})
  end
end
