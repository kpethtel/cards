defmodule CardsWeb.PageController do
  use CardsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
