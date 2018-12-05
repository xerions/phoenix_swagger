# Getting Started

`PhoenixSwagger` provides a mix compiler and mix task `phx.swagger.generate` for the swagger-ui `json`
file generation that contains swagger specification that describes API of the `phoenix`
application.

You just need to add the swagger DSL to your controllers and then run this one mix task
to generate the json files.

## Installation

To use `PhoenixSwagger` with a phoenix application just add it to your list of
dependencies in the `mix.exs` file:

```elixir
def deps do
  [
    {:phoenix_swagger, "~> 0.8"},
    {:ex_json_schema, "~> 0.5"} # optional
  ]
end
```

`ex_json_schema` is an optional dependency of `phoenix_swagger` required only for schema validation plug and test helper.

Append `:phoenix_swagger` to the list of compilers to automatically update the swagger files each time the app is compiled:

```elixir
def project do
[
  ...
  compilers: [:phoenix, :gettext] ++ Mix.compilers ++ [:phoenix_swagger],
  ...
end
```

## Configuration

Add a config entry to your phoenix application specifying the output filename, router and endpoint modules used to generate the swagger file:

```elixir
config :my_app, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: MyAppWeb.Router,     # phoenix routes will be converted to swagger paths
      endpoint: MyAppWeb.Endpoint  # (optional) endpoint config used to set host, port and https schemes.
    ]
  }
```

If multiple swagger files need to be generated, add additional entries to the project config:

```elixir
config :my_app, :phoenix_swagger,
  swagger_files: %{
    "booking-api.json" => [router: MyApp.BookingRouter],
    "reports-api.json" => [router: MyApp.ReportsRouter],
    "admin-api.json" => [router: MyApp.AdminRouter]
  }
```

## Router

The outline of the swagger document should be returned from a `swagger_info/0` function
defined in your phoenix `Router.ex` module.

```elixir
defmodule MyApp.Router do
  use MyApp.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", MyApp do
    pipe_through :api
    resources "/users", UserController
  end

  def swagger_info do
    %{
      info: %{
        version: "1.0",
        title: "My App"
      }
    }
  end
end
```

The `version` and `title` are mandatory fields. By default the `version` will be `0.0.1`
and the `title` will be `<enter your title>` if you do not provide `swagger_info/0`
function.

See the [Swagger Object specification](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md#swagger-object) for details
of other information that can be included. `basePath` is optional but may need to be specified if your API routes do not reside at the root location `/`. You can also set the description of `tags` here, for example:

```elixir
%{
  basePath: "/api",
  info: %{..},
  tags: [%{name: "Users", description: "Operations about Users"}]
}
```

## Endpoint

The swagger `host` value is built from your phoenix `Endpoint` `url` config.

```elixir
# config.exs
config :my_app, MyApp.Web.Endpoint,
  url: [host: "localhost"], # "host": "localhost:4000" in generated swagger
```

If the `host` is configured to be set dynamically (either by `{:systems, "VAR"}` tuples or the `:load_from_system_env` flag), the swagger host will be omitted. SwaggerUI will default to sending requests to the same host that is serving the swagger file.

```elixir
# prod.exs
config :my_app, MyApp.Web.Endpoint,
  load_from_system_env: true, # Expects url host and port to be configured in Endpoint.init callback
  url: [host: "example.com", port: 80],
```

## Generate Swagger File

Once you have a minimal configuration and `swagger_info` function in the router, run the `phx.swagger.generate`
mix task for the `swagger` json file generation into directory with `phoenix` application:

```
mix phx.swagger.generate
```
