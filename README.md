# PhoenixSwagger [![Build Status](https://travis-ci.org/xerions/phoenix_swagger.svg?branch=master)](https://travis-ci.org/xerions/phoenix_swagger)

`PhoenixSwagger` is the library that provides [swagger](http://swagger.io/) integration
to the [phoenix](http://www.phoenixframework.org/) web framework.
The `PhoenixSwagger` generates `Swagger` specification for `Phoenix` controllers and
validates the requests.

## Installation

`PhoenixSwagger` provides `phoenix.swagger.generate` mix task for the swagger-ui `json`
file generation that contains swagger specification that describes API of the `phoenix`
application.

You just need to add the swagger DSL to your controllers and then run this one mix task
to generate the json files.

To use `PhoenixSwagger` with a phoenix application just add it to your list of
dependencies in the `mix.exs` file:

```elixir
def deps do
  [{:phoenix_swagger, "~> 0.4.0"}]
end
```

Now you can use `phoenix_swagger` to generate `swagger-ui` file for you application.

## Usage

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

See the [swaggerObject specification](http://swagger.io/specification/#swaggerObject) for details
of other information that can be included.


## Swagger Path DSL

`PhoenixSwagger` provides `swagger_path/2` macro that generates swagger specification
for the certain phoenix controller action.

Example:

```elixir
use PhoenixSwagger

swagger_path :index do
  get "/posts"
  description "List blog posts"
  responses 200, "Success"
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
      end
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
      relationship :posts
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

After adding swagger spec to you controllers, recompile your app `mix phoenix.server`, then run the `phoenix.swagger.generate`
mix task for the `swagger-ui` json file generation into directory with `phoenix` application:

```
mix phoenix.swagger.generate
```

As the result there will be `swagger.json` file into root directory of the `phoenix` application.
To generate `swagger` file with the custom name/place, pass it to the main mix task:

```
mix phoenix.swagger.generate ~/my-phoenix-api.json
```

If the project contains multiple `Router` modules, you can generate a swagger file for each one by specifying the router module as an argument to `mix phoenix.swagger.generate`:

```
mix phoenix.swagger.generate booking-api.json -r MyApp.BookingRouter
mix phoenix.swagger.generate reports-api.json -r MyApp.ReportsRouter
mix phoenix.swagger.generate admin-api.json -r MyApp.AdminRouter
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

Before usage of swagger validator, add the `PhoenixSwagger.Validator.Supervisor` to the supervisor tree of
your application.

The `phoenix_swagger` provides `PhoenixSwagger.Validator.parse_swagger_schema/1` API to load a swagger schema by
the given path or list of paths. This API should be called during application startup to parse/load a swagger schema.

After this, the `PhoenixSwagger.Validator.validate/2` can be used to validate resources.

For example:

```elixir
iex(1)> Validator.validate("/history", %{"limit" => "10"})
{:error,"Type mismatch. Expected Integer but got String.", "#/limit"}

iex(2)> Validator.validate("/history", %{"limit" => 10, "offset" => 100})
:ok
```

Besides `validate/2` API, the `phoenix_swagger` validator can be used via Plug to validate
intput parameters of your controllers.

Just add `PhoenixSwagger.Plug.Validate` plug to your router:

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

## Swagger UI

PhoenixSwagger includes a plug with all static assets required to host swagger-ui from your Phoenix application.

Usage:

Generate a swagger file and place it in your applications `priv/static` dir:

```
mix phoenix.swagger.generate priv/static/myapp.json
```

Add a swagger scope to your router, and forward all requests to SwaggerUI

```elixir
    scope "/api/swagger" do
      forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :myapp, swagger_file: "swagger.json"
    end
```

Run the server with `mix phoenix.server` and browse to `localhost:8080/api/swagger/`,
Swagger-ui should be shown with your swagger spec loaded.

See the `examples/simple` project for a runnable example with swagger-ui.
