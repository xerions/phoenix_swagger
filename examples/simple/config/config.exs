# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :simple,
  ecto_repos: [Simple.Repo]

# Configures the endpoint
config :simple, SimpleWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "zF/nkuOvpNhuSI/bBYTk6GCv+CvEZLZ9rjO/XeOaEAnG/YkCWtXVcZG3XsoTXs2q",
  render_errors: [view: SimpleWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Simple.PubSub,
  live_view: [signing_salt: "/Bz8Xixi"]

config :simple, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: SimpleWeb.Router]
  }

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :phoenix_swagger, json_library: Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
