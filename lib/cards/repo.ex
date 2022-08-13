defmodule Cards.Repo do
  use Ecto.Repo,
    otp_app: :cards,
    adapter: Ecto.Adapters.Postgres
end
