defmodule Zockelo.Repo do
  use Ecto.Repo,
    otp_app: :zockelo,
    adapter: Ecto.Adapters.Postgres
end
