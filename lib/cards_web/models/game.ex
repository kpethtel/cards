defmodule CardsWeb.Game do
  use GenServer
  require Logger

  def start_link(name: name) do
    Logger.info("received name: #{name}")
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:add, name}, state) do
    Logger.info("I MADE IT 2")
    Logger.info("name #{name}")

    state = [name | state]
    Logger.info("STATE")
    Logger.info(state)
    {:noreply, state}
  end

  def add_message(pid, name) do
    Logger.info("I MADE IT 1")
    GenServer.cast(pid, {:add, name})
  end
end
