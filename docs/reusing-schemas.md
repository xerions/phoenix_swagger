# Reusing swagger schemas

When building an API it can be common to have schemas that are common to multiple actions.

## Scenario

For example, let's say we've got two endpoints:
- `GET /projects`
- `GET /books`

Both of these endpoints can have an erroneous responses like `401 Unauthorized`.
We don't want to define our new `Error` schema for both of these endpoints. This will create
duplicate code and we just want to keep our code [DRY](https://cs.wikipedia.org/wiki/Don%27t_repeat_yourself).

Here's what the swagger spec in our `ProjectsController` and `BookController` would look like:

```elixir
defmodule ProjectsController do
  use HelloWeb, :controller
  use PhoenixSwagger

  swagger_path :index do
    get "/projects"
    produces "application/json"
    parameter("Authorization", :header, :string, "OAuth2 access token", required: true)
    parameters do      
      sort_by :query, :string, "The property to sort by"
      sort_direction :query, :string, "The sort direction", enum: [:asc, :desc], default: :asc
      company_id :string, :query, "The company id"
    end
    response(200, "OK", Schema.ref(:ListOfProjects))
    response(401, "Unauthorized", Schema.ref(:Error))
  end
  
  

  @doc false
  def swagger_definitions do
    %{
        ListOfProjects: ...schema definition...,
        Error: 
          swagger_schema do
            properties do
              code(:string, "Error code", required: true)
              message(:string, "Error message", required: true)
            end
          end
      } 
  end
end
```

```elixir
defmodule BooksController do
  use HelloWeb, :controller
  use PhoenixSwagger

  swagger_path :index do
    get "/books"
    produces "application/json"
    parameter("Authorization", :header, :string, "OAuth2 access token", required: true)
    parameters do      
      sort_by :query, :string, "The property to sort by"
      sort_direction :query, :string, "The sort direction", enum: [:asc, :desc], default: :asc
      company_id :string, :query, "The company id"
    end
    response(200, "OK", Schema.ref(:ListOfBooks))
    response(401, "Unauthorized", Schema.ref(:Error))
  end
  
  

  @doc false
  def swagger_definitions do
    %{
        ListOfBooks: ...schema definition...,
        Error: 
          swagger_schema do
            properties do
              code(:string, "Error code", required: true)
              message(:string, "Error message", required: true)
            end
          end
      } 
  end
end
```

Our ProjectsController and BooksControllers have now identical `Error` schema defined in their modules.


## Extracting schemas into a module for reuse

We can easily extract common schemas into an ordinary elixir module. This module has to implement `PhoenixSwagger`
behaviour which understands `phoenix_swagger` macros for defining schemas.

```elixir
defmodule CommonSchemas do
  @moduledoc "Common schema declarations for phoenix swagger"
  
  use PhoenixSwagger
  
  @doc """
  Returns map of common swagger definitions merged with the map of provided schema definitions.

  The common definitions (data structures) are not specific to any controller or
  business domain logic.
  """
  def create_swagger_definitions(%{} = schemas) do
    Map.merge(
      %{
        Error: 
          swagger_schema do
            properties do
              code(:string, "Error code", required: true)
              message(:string, "Error message", required: true)
            end
          end,
        Errors:
          swagger_schema do
              properties do
                errors(
                  Schema.new do
                    title("Errors")
                    description("A collection of Errors")
                    type(:array)
                    items(Schema.ref(:Error))
                  end
                )
              end
          end          
      },
      schemas
    )
  end
end
```

As you can see, it is also possible to reference other common schemas defined inside the `create_swagger_definitions/1`.

## Reusing the common schemas

Now, instead of defining the `Error` schema in every controller, we can just use `create_swagger_definitions/1`
inside our controllers.

```elixir
defmodule ProjectsController do
  import CommonSchemas, only: [create_swagger_definitions: 1]

  use HelloWeb, :controller
  use PhoenixSwagger

  swagger_path :index do
    get "/projects"
    produces "application/json"
    parameter("Authorization", :header, :string, "OAuth2 access token", required: true)
    parameters do      
      sort_by :query, :string, "The property to sort by"
      sort_direction :query, :string, "The sort direction", enum: [:asc, :desc], default: :asc
      company_id :string, :query, "The company id"
    end
    response(200, "OK", Schema.ref(:ListOfProjects))
    response(401, "Unauthorized", Schema.ref(:Error))
  end
  
  

  @doc false
  def swagger_definitions do
    create_swagger_definitions(%{
        ListOfProjects: ...schema definition...
    })  
  end
end
```

```elixir
defmodule BooksController do
  import CommonSchemas, only: [create_swagger_definitions: 1]

  use HelloWeb, :controller
  use PhoenixSwagger
  
  swagger_path :index do
    get "/books"
    produces "application/json"
    parameter("Authorization", :header, :string, "OAuth2 access token", required: true)
    parameters do      
      sort_by :query, :string, "The property to sort by"
      sort_direction :query, :string, "The sort direction", enum: [:asc, :desc], default: :asc
      company_id :string, :query, "The company id"
    end
    response(200, "OK", Schema.ref(:ListOfBooks))
    response(401, "Unauthorized", Schema.ref(:Error))
  end
  
  

  @doc false
  def swagger_definitions do
    create_swagger_definitions(%{
        ListOfBooks: ...schema definition...
    }) 
  end
end
```

To avoid importing `create_swagger_definitions/1` in every controller, find a `HelloWeb` module and add an import
inside the `controller/0` function. This module will be called differently in your project depending on the the name of your 
Phoenix project: `<PhoenixProjectName>Web`. This file is the entrypoint for defining your web interface and is part
of every Phoenix installation.


```elixir
defmodule HelloWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use HelloWeb, :controller
      use HelloWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: HelloWeb

      import Plug.Conn
      import CommonSchemas, only: [create_swagger_definitions: 1]
      
      alias HelloWeb.Router.Helpers, as: Routes
    end
  end
end
```

