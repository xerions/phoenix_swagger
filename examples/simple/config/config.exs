# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :simple,
  ecto_repos: [Simple.Repo]

# Configures the endpoint
config :simple, Simple.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "occcf4JQ1yY8UbMxsqJx0+wxhrQFQMvAJi+mYlaWCSJxmmrgGLyt4eZ9oFhrisRP",
  render_errors: [view: Simple.Web.ErrorView, accepts: ~w(json)],
  pubsub: [name: Simple.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
