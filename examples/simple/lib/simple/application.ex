defmodule Simple.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    PhoenixSwagger.Validator.parse_swagger_schema("priv/static/swagger.json")

    children = [
      # Start the Ecto repository
      Simple.Repo,
      # Start the Telemetry supervisor
      SimpleWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Simple.PubSub},
      # Start the Endpoint (http/https)
      SimpleWeb.Endpoint
      # Start a worker by calling: Simple.Worker.start_link(arg)
      # {Simple.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Simple.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SimpleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
