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

    state = Map.put(state, name, %{messages: []})
    Logger.info("STATE")
    Logger.info(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_message, username, message}, state) do
    Logger.info("ADDING MESSAGE TO STATE")
    message_list = get_in(state, [username, :messages])
    message_list = [message | message_list]
    state = put_in(state, [username, :messages], message_list)
    Logger.info("STATE")
    Logger.info(state)
    {:noreply, state}
  end

  def add_user(server, name) do
    Logger.info("ADDING USER")
    GenServer.cast(server, {:add, name})
  end

  def add_message(server, username, message) do
    Logger.info("ADDING MESSAGE")
    Logger.info(message)
    Logger.info(username)
    GenServer.cast(server, {:add_message, username, message})
  end
end
