# PhoenixSwagger [![Build Status](https://travis-ci.org/xerions/phoenix_swagger.svg?branch=master)](https://travis-ci.org/xerions/phoenix_swagger)

`PhoenixSwagger` is the library that provides [swagger](http://swagger.io/) integration
to the [phoenix](http://www.phoenixframework.org/) web framework.
The `PhoenixSwagger` generates `Swagger` specification for `Phoenix` controllers and
validates the requests.

## Installation

`PhoenixSwagger` provides a mix compiler and mix task `phx.swagger.generate` for the swagger-ui `json`
file generation that contains swagger specification that describes API of the `phoenix`
application.

You just need to add the swagger DSL to your controllers and then run this one mix task
to generate the json files.

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

Add `:phoenix_swagger` to the list of compilers to automatically update the swagger files each time the app is compiled:

```elixir
def project do
[
  ...
  compilers: [:phoenix, :gettext, :phoenix_swagger] ++ Mix.compilers,
  ...
end
```

Now you can use `phoenix_swagger` to generate `swagger-ui` file for you application.

## Usage

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
of other information that can be included. You can set the description of `tags` here for example:
```elixir
%{
  info: %{..},
  tags: [%{name: "Users", description: "Operations about Users"}]
}
```

The swagger `host` value is built from your phoenix `Endpoint` `url` config.

```elixir
# config.exs
config :my_app, MyApp.Web.Endpoint,
  url: [host: "localhost"], # "host": "localhost:4000" in generated swagger
```

If the `host` is configured to be set dynamically (either by {:systems, "VAR"} tuples or the :load_from_system_env flag), "the swagger host will be omitted. SwaggerUI will default to sending requests to the same host that is serving the swagger file.

```elixir
# prod.exs
config :my_app, MyApp.Web.Endpoint,
  load_from_system_env: true, # Expects url host and port to be configured in Endpoint.init callback
  url: [host: {:system, "HOST"}, port: {:system, "PORT"}], # alternatively using tuples for configuration
```

## Swagger Path DSL

`PhoenixSwagger` provides `swagger_path/2` macro that generates swagger specification
for the certain phoenix controller action.

Example:

```elixir
use PhoenixSwagger

swagger_path :index do
  get "/posts"
  description "List blog posts"
  response 200, "Success"
end

def index(conn, _params) do
  posts = Repo.all(Post)
  render(conn, "index.json", posts: posts)
end
```

The `swagger_path` macro takes two parameters:

* Name of controller action;
* `do` block that contains the `swagger` specification for the controller action.

Within the do-end block, the DSL provided by the `PhoenixSwagger.Path` module can be used.
The DSL always starts with one of the `get`, `put`, `post`, `delete`, `head`, `options` functions,
followed by any functions with first argument being a `PhoenixSwagger.Path.PathObject` struct.

Example:

```elixir
swagger_path :index do
  get "/api/v1/{org_id}/users"
  summary "Query for users"
  description "Query for users. This operation supports with paging and filtering"
  produces "application/json"
  tag "Users"
  operation_id "list_users"
  paging
  parameters do
    org_id :path, :string, "Organization ID", required: true
    zipcode :query, :string, "Address Zip Code", required: true, example: "90210"
    include :query, :array, "Related resources to include in response",
              items: [type: :string, enum: [:organisation, :favourites, :purchases]],
              collectionFormat: :csv
  end
  response 200, "OK", Schema.ref(:Users)
  response 400, "Client Error"
end
```

The `swagger_path` macro layer is just some syntactic sugar over regular elixir functions. Therefore it can easily be extended, for instance, if we want to reuse some common parameters.

For more details on this take a look at [Reusing Swagger Parameters](https://hexdocs.pm/phoenix_swagger/reusing-swagger-parameters.html).

## Swagger Schema DSL

Response schema definitions are placed in a `swagger_definitions/0` function within each controller module.
This function should return a map in the format of a swagger [definitionsObject](http://swagger.io/specification/#definitionsObject).

The `swagger_schema/2` macro can be used to build a schema definition using the functions provided by the `PhoenixSwagger.Schema` module.

Example:

```elixir
def swagger_definitions do
  %{
    User: swagger_schema do
      title "User"
      description "A user of the application"
      properties do
        name :string, "Users name", required: true
        id :string, "Unique identifier", required: true
        address :string, "Home address"
        preferences (Schema.new do
          properties do
            subscribe_to_mailing_list :boolean, "mailing list subscription", default: true
            send_special_offers :boolean, "special offers list subscription", default: true
          end
        end)
      end
      example %{
        name: "Joe",
        id: "123",
        address: "742 Evergreen Terrace"
      }
    end,
    Users: swagger_schema do
      title "Users"
      description "A collection of Users"
      type :array
      items Schema.ref(:User)
    end
  }
end
```

## JSON:API Helpers

The `PhoenixSwagger.JsonApi` module provides helpers for constructing JSON:API schemas easily.
`PhoenixSwagger.JsonApi.resource/1` describes a JSON:API [resource object](http://jsonapi.org/format/#document-resource-objects).
`PhoenixSwagger.JsonApi.page/1` and `PhoenixSwagger.JsonApi.single/1` can then be used to wrap a resource in a JSON:API [top level object](http://jsonapi.org/format/#document-top-level)

Example:

```elixir
use PhoenixSwagger

def swagger_definitions do
  %{
    UserResource: JsonApi.resource do
      description "A user that may have one or more supporter pages."
      attributes do
        phone :string, "Users phone number"
        full_name :string, "Full name"
        user_updated_at :string, "Last update timestamp UTC", format: "ISO-8601"
        user_created_at :string, "First created timestamp UTC"
        email :string, "Email", required: true
        birthday :string, "Birthday in YYYY-MM-DD format"
        address Schema.ref(:Address), "Users address"
      end
      link :self, "The link to this user resource"
      relationship :preferences
      relationship :posts, type: :has_many
    end,
    Users: JsonApi.page(:UserResource),
    User: JsonApi.single(:UserResource)
  }
end

swagger_path :index do
  get "/api/v1/users"
  paging size: "page[size]", number: "page[number]"
  response 200, "OK", Schema.ref(:Users)
end
```

## Generate Swagger File

After adding swagger spec to you controllers, run the `phx.swagger.generate`
mix task for the `swagger-ui` json file generation into directory with `phoenix` application:

```
mix phx.swagger.generate
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

For more informantion, you can find `swagger` specification [here](https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md).

## Validator

Besides generator of `swagger` schemas, the `phoenix_swagger` provides validator of input parameters of resources.

Suppose you have following resource in your schema:

```
...
...
"/history": {
    "get": {
        "parameters": [
        {
            "name": "offset",
            "in": "query",
            "type": "integer",
            "format": "int32",
            "description": "Offset the list of returned results by this amount. Default is zero."
        },
        {
            "name": "limit",
            "in": "query",
            "type": "integer",
            "format": "int32",
            "description": "Integer of items to retrieve. Default is 5, maximum is 100."
        }]
     }
}
...
...
```

The `phoenix_swagger` provides `PhoenixSwagger.Validator.parse_swagger_schema/1` API to load a swagger schema by
the given path or list of paths. This API should be called during application startup to parse/load a swagger schema.

After this, use one of the following to validate resources:
* the function `PhoenixSwagger.Validator.validate/2` using request path and parameters
* the default Plug `PhoenixSwagger.Plug.Validate`
* the function `PhoenixSwagger.ConnValidate.validate/1` using `conn`

### `Validator.validate/2`

For example:

```elixir
iex(1)> Validator.validate("/history", %{"limit" => "10"})
{:error,"Type mismatch. Expected Integer but got String.", "#/limit"}

iex(2)> Validator.validate("/history", %{"limit" => 10, "offset" => 100})
:ok
```


### Default Plug

To validate input parameters of your controllers with the default Plug, just add `PhoenixSwagger.Plug.Validate` to your router:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug PhoenixSwagger.Plug.Validate
end

scope "/api", MyApp do
  pipe_through :api
  post "/users", UsersController, :send
end
```

On validation errors, the default Plug returns `400` with the following body:
```json
{
  "error": {
    "path": "#/path/to/schema",
    "message": "Expected integer, got null"
  }
}
```

The return code for validation errors is configurable via `:validation_failed_status` parameter.
If `conn.private[:phoenix_swagger][:valid]` is set to `true`, the Plug will skip validation.

The current minimal version of elixir should be `1.3` and in this case you must add `phoenix_swagger` application
to the application list in your `mix.exs`.

### `ConnValidator.validate/1`

Use `ConnValidator.validate/1` to build your own Plugs. It accepts a `conn` and returns `:ok` on validation success. Refer to source for error cases.

## Test Response Validator

PhoenixSwagger also includes a testing helper module `PhoenixSwagger.SchemaTest` to conveniently assert that responses
from Phoenix controller actions conform to your swagger schema.

In your controller test files add the `PhoenixSwagger.SchemaTest` mixin with the path to your swagger spec:

```elixir
defmodule YourApp.UserControllerTest do
  use YourApp.ConnCase, async: true
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
```

Then in each test, the context will contain the swagger_schema, which can be used with
the `validate_resp_schema` function:

```elixir
test "shows chosen resource", %{conn: conn, swagger_schema: schema} do
  user = Repo.insert! struct(User, @valid_attrs)
  response =
    conn
    |> get(user_path(conn, :show, user))
    |> validate_resp_schema(schema, "UserResponse")
    |> json_response(200)
end
```

## Swagger UI

PhoenixSwagger includes a plug with all static assets required to host swagger-ui from your Phoenix application.

Usage:

Generate a swagger file in your applications `priv/static` dir:

```
config :my_app, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: MyAppWeb.Router]
  }
```

```
mix phx.swagger.generate
```

Add a swagger scope to your router, and forward all requests to SwaggerUI

```elixir
    scope "/api/swagger" do
      forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :myapp, swagger_file: "swagger.json"
    end
```

Run the server with `mix phoenix.server` and browse to `localhost:4000/api/swagger`,
Swagger-ui should be shown with your swagger spec loaded.

See the `examples/simple` project for a runnable example with swagger-ui.

## Live Reload

Live reloading can be use to automatically regenerate the swagger files and reload the swagger-ui when controller files change.
To enable live reloading:

 - Ensure `phoenix_swagger` is added as a compiler in your `mix.exs` file
 - Add the path to the swagger json files and controllers to the endpoint `live_reload` config
 - Add the `reloadable_compilers` configuration to the endpoint config, including the `:phoenix_swagger` compiler

```elixir
config :your_app, YourApp.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg|json)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/your_app_web/views/.*(ex)$},
      ~r{lib/your_app_web/controllers/.*(ex)$},
      ~r{lib/your_app_web/templates/.*(eex)$}
    ]
  ],
  reloadable_compilers: [:gettext, :phoenix, :elixir, :phoenix_swagger]
```
