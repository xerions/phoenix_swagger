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
  [{:phoenix_swagger, "~> 0.3.0"}]
end
```

Now you can use `phoenix_swagger` to generate `swagger-ui` file for you application.

## Usage

To generate [Info Object](https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#infoObject)
you must provide `swagger_info/0` function in your `mix.exs` file. This function returns
a keyword list that contains `Info Object` fields:

```elixir
def swagger_info do
  [version: "0.0.0", title: "My awesome phoenix application"]
end
```

The `version` and `title` are mandatory fields. By default the `version` will be `0.0.1`
and the `title` will be `<enter your title>` if you will not provide `swagger_info/0`
function.

Fields that can be in the `swagger_info`:

Name           | Required | Type                                   | Default value
-------------- | -------- | -------------------------------------- | -------------
title          | true     | string                                 | `<enter your title>`
version        | true     | string                                 | `0.0.1`
description    | false    | string                                 |                                          
termsOfService | false    | string                                 |                    
contact        | false    | [name: "...", url: "...", email:"..."] |                    
license        | false    | [name: "...", url: "..."]              |                      

`PhoenixSwagger` provides `swagger_model/2` macro that generates swagger specification
for the certain phoenix controller.

Example:

```elixir
use PhoenixSwagger

swagger_model :index do
  description "Short description"
  parameter :query, :id, :integer, :required, "Property id"
  responses 200, "Description"
end

def index(conn, _params) do
  posts = Repo.all(Post)
  render(conn, "index.json", posts: posts)
end
```

The `swagger_model` macro takes two parameters:

* Name of controller action;
* `do` block that contains `swagger` definitions.

The `PhoenixSwagger` supports three definitions:

1. The `description` takes one elixir's `String` and provides short description for the
given controller action.

2. The `parameter` provides description of the routing parameter for the given action and
may take five parameters:

* The location of the parameter. Possible values are `query`, `header`, `path`, `formData` or `body`. [required];
* The name of the parameter. [required];
* The type of the parameter. Allowed only [swagger data types](https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#data-types
) [required];
* Determines whether this parameter is mandatory, just remove it if a parameter non-required;
* Description of a parameter. Can be elixir's `String` or function/0 that returns elixir's string;

Note that order of parameters is important now.

And the third definition is `responses` that takes three parameters (third parameter is not mandatory)
and generates definition of the response for the given controller action. The first argument is http
status code and has `:integer` data type. The second is the short description of the response. The third
non-mandatory field is a schema of the response. It must be elixir `function/0` that returns a map in a
swagger schema format.

For example:

```elixir
use PhoenixSwagger

swagger_model :get_person do
  description "Get persons according to the age"
  parameter :query, :id, :integer, :required
  responses 200, "Description", schema
end

def schema do
  %{type: :array, title: "Persons",
    items:
      %{title: "Person", type: :object, properties: %{ name: %{type: :string}}}
   }
  end

def get_person_schema(conn, _params) do
    ...
    ...
    ...
end
```

That's all. Recompile your app `mix phoenix.server`, then run the `phoenix.swagger.generate`
mix task for the `swagger-ui` json file generation into directory with `phoenix` application:

```
mix phoenix.swagger.generate
```

As the result there will be `swagger.json` file into root directory of the `phoenix` application.
To generate `swagger` file with the custom name/place, pass it to the main mix task:

```
mix phoenix.swagger.generate ~/my-phoenix-api.json
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
