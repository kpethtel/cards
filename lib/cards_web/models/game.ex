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
    state = put_in(state, [username, :links], links)
    {:noreply, state}
  end

  @impl true
  def handle_call({:fetch_link, username, direction}, _from, state) do
    Logger.info("HANDLE IMAGE CALL")
    links = get_in(state, [username, :links])
    new_links = if (direction == "previous") do
      Logger.info("PREVIOUSING")
      {tail_tip, long_head} = List.pop_at(links, -1)
      [tail_tip | long_head]
    else
      Logger.info("NEXTING")
      {head, tail} = List.pop_at(links, 0)
      List.insert_at(tail, -1, head)
    end
    new_image = Enum.fetch(new_links, 0)
    state = put_in(state, [username, :links], new_links)
    {:reply, new_image, state}
  end

  def add_user(server, name) do
    Logger.info("ADDING USER")
    GenServer.cast(server, {:add, name})
  end

  def add_image_links(server, username, links) do
    Logger.info("ADDING IMAGES")
    GenServer.cast(server, {:add_links, username, links})
  end

  def fetch_image_from_state(server, username, direction) do
    Logger.info("FETCHING IMAGE FROM STATE")
    GenServer.call(server, {:fetch_link, username, direction})
  end
end
