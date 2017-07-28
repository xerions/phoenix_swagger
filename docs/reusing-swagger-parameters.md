# Reusing swagger parameters

When building an API it can be common to have headers or parameters that are common to multiple actions.

## Scenario

For example, let's say we've got two endpoints:
- `GET /projects`
- `GET /books`

Both of these endpoints can be sorted using by `sort_by` and `sort_direction` parameters and both require an Authorization header.

Here's what the swagger spec in our `ProjectsController` would look like:

```elixir
defmodule ProjectsController do
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
  end
end
```

Our BooksController swagger would look very similar, also defining the `Authorization` header and the `sort_by` and `sort_direction` headers.

## Extracting parameters into a module for reuse

The `swagger_path` macro layer is actually just some syntactic sugar over regular elixir functions, intended to be easily extended. Any function that accepts a `%PhoenixSwagger.Path.PathObject{}` as its first argument and returns an updated `%PathObject{}` can be used in the `swagger_path` macro.

Knowing this, we can easily extract some of the common logic into a module and reuse it in our controllers.

```elixir
defmodule CommonParameters do
  @moduledoc "Common parameter declarations for phoenix swagger"

  alias PhoenixSwagger.Path.PathObject
  import PhoenixSwagger.Path

  def authorization(path = %PathObject{}) do
    path |> parameter("Authorization", :header, "OAuth2 access token", required: true)
  end

  def sorting(path = %PathObject{}) do
    path
    |> parameter(:sort_by, :query, :string, "The property to sort by")
    |> parameter(:sort_direction, :query, :string, "The sort direction", enum: [:asc, :desc], default: :asc)
  end
end
```

This can also be done using the `parameters` macro:

```elixir
def sorting(path = %PathObject{}) do
  parameters path do
    sort_by :query, :string, "The property to sort by"
    sort_direction :query, :string, "The sort direction", enum: [:asc, :desc], default: :asc
  end
end
```

## Reusing the common parameters

Now, instead of defining these parameters in every controller, we can just reference the `CommonParameters` module:

```elixir
defmodule ProjectsController do
  use PhoenixSwagger

  swagger_path :index do
    get "/users"
    produces "application/json"
    CommonParameters.authorization
    CommonParameters.sorting
    parameters do
      company_id :string, :query, "The company id"
    end
  end
end
```
