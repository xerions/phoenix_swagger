defmodule Simple.Repo do
  use Ecto.Repo,
    otp_app: :simple,
    adapter: Ecto.Adapters.Postgres
end
