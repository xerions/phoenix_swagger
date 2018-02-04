use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :simple, SimpleWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg|json)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/simple_web/views/.*(ex)$},
      ~r{lib/simple_web/controllers/.*(ex)$},
      ~r{lib/simple_web/templates/.*(eex)$}
    ]
  ],
  reloadable_compilers: [:gettext, :phoenix, :elixir, :phoenix_swagger]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :simple, Simple.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "simple_dev",
  hostname: "localhost",
  pool_size: 10
