defmodule PhoenixSwagger do

  use Application
  alias PhoenixSwagger.Path
  alias PhoenixSwagger.Path.PathObject

  @moduledoc """
  The PhoenixSwagger module provides macros for defining swagger operations and schemas.

  Example:

      use PhoenixSwagger

      swagger_path :create do
        post "/api/v1/{team}/users"
        summary "Create a new user"
        consumes "application/json"
        produces "application/json"
        parameters do
          user :body, Schema.ref(:User), "user attributes"
          team :path, :string, "Users team ID"
        end
        response 200, "OK", Schema.ref(:User)
      end

      def swagger_definitions do
        %{
          User: swagger_schema do
            title "User"
            description "A user of the application"
            properties do
              name :string, "Users name", required: true
              id :string, "Unique identifier", required: true
              address :string, "Home adress"
            end
          end
        }
      end
  """

  @table :validator_table

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Test.Worker, [arg1, arg2, arg3]),
    ]

    :ets.new(@table, [:public,:named_table])

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Test.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defmacro __using__(_) do
    quote do
      import PhoenixSwagger
      require PhoenixSwagger.Schema, as: Schema
      require PhoenixSwagger.JsonApi, as: JsonApi
    end
  end

  @doc """
  Builds a swagger schema map using a DSL from the functions defined in `PhoenixSwagger.Schema`.

  ## Example

      iex> use PhoenixSwagger
      ...> swagger_schema do
      ...>   title "Pet"
      ...>   description "A pet in the pet store"
      ...>   properties do
      ...>     id :integer, "Unique identifier", required: true, format: :int64
      ...>     name :string, "Pets name", required: true
      ...>     tags array(:string), "Tag categories for this pet"
      ...>   end
      ...>   additional_properties false
      ...> end
      %{
        "title" => "Pet",
        "type" => "object",
        "description" => "A pet in the pet store",
        "properties" => %{
          "id" => %{
            "description" => "Unique identifier",
            "format" => "int64",
            "type" => "integer"
          },
         "name" => %{
            "description" => "Pets name",
            "type" => "string"
          },
          "tags" => %{
            "description" => "Tag categories for this pet",
            "items" => %{
              "type" => "string"
            },
            "type" => "array"
          }
        },
        "required" => ["name", "id"],
        "additionalProperties" => false
      }

      iex> use PhoenixSwagger
      ...> swagger_schema do
      ...>   title "Phone"
      ...>   description "An 8 digit phone number with optional 2 digit area code"
      ...>   type :string
      ...>   max_length 11
      ...>   pattern ~S"^(\([0-9]{2}\))?[0-9]{4}-[0-9]{4}$"
      ...> end
      %{
        "description" => "An 8 digit phone number with optional 2 digit area code",
        "maxLength" => 11,
        "pattern" => "^(\\([0-9]{2}\\))?[0-9]{4}-[0-9]{4}$",
        "title" => "Phone",
        "type" => "string"
      }
  """
  defmacro swagger_schema(block) do
    exprs = case block do
      [do: {:__block__, _, exprs}] -> exprs
      [do: expr] -> [expr]
    end

    acc = quote do %Schema{type: :object} end
    body = Enum.reduce(exprs, acc, fn expr, acc ->
      quote do unquote(acc) |> unquote(expr) end
    end)

    # Immediately invoked anonymous function for locally scoped import
    quote do
      (fn ->
        import PhoenixSwagger.Schema
        alias PhoenixSwagger.Schema
        unquote(body)
        |> PhoenixSwagger.to_json()
      end).()
    end
  end

  @doc """
    Swagger operations (aka "paths") are defined inside a `swagger_path` block.

    Within the do-end block, the DSL provided by the `PhoenixSwagger.Path` module can be used.
    The DSL is any chain of functions with first argument being a `PhoenixSwagger.Path.PathObject` struct.

    The verb and path can be set explicitly using the `get`, `put`, `post`, `patch`, `delete` functions, or
    inferred from the phoenix router automatically.

    Swagger `tags` will default to match the module name with trailing `Controller` removed.
    Eg operations defined in module MyApp.UserController will have `tags: ["User"]`.

    Swagger `operationId` will default to the fully qualified action function name.
    Eg `index` action in `MyApp.UserController` will have `operationId: "MyApp.UserController.index"`.

    ## Example

        defmodule ExampleController do
          use ExampleApp.Web, :controller
          use PhoenixSwagger

          swagger_path :index do
            get "/users"
            summary "Get users"
            description "Get users, filtering by account ID"
            parameter :query, :id, :integer, "account id", required: true
            response 200, "Description", :Users
            tag "users"
          end

          def index(conn, _params) do
            posts = Repo.all(Post)
            render(conn, "index.json", posts: posts)
          end
        end
    """
    defmacro swagger_path(action, [do: {:__block__, _, [first_expr | exprs]}]) do
      fun_name = "swagger_path_#{action}" |> String.to_atom
      body = Enum.reduce(exprs, first_expr, fn expr, acc ->
              quote do unquote(acc) |> unquote(expr) end
             end)

      quote do
        def unquote(fun_name)(route) do
          import PhoenixSwagger.Path

          %PhoenixSwagger.Path.PathObject{}
          |> unquote(body)
          |> PhoenixSwagger.ensure_operation_id(__MODULE__, unquote(action))
          |> PhoenixSwagger.ensure_tag(__MODULE__)
          |> PhoenixSwagger.ensure_verb_and_path(route)
          |> PhoenixSwagger.Path.nest()
          |> PhoenixSwagger.to_json()
        end
      end
    end

  @doc false
  # Add a default operationId based on model name and action if required
  def ensure_operation_id(path = %PathObject{operation: %{operationId: ""}}, module, action) do
    Path.operation_id(path, String.replace_prefix("#{module}.#{action}", "Elixir.", ""))
  end
  def ensure_operation_id(path, _module, _action), do: path

  @doc false
  # Add a default tag based on controller module name if none present
  def ensure_tag(path = %PathObject{operation: %{tags: []}}, module) do
    tags =
      module
      |> Module.split()
      |> Enum.reverse()
      |> hd()
      |> String.split("Controller")
      |> Enum.filter(&(String.length(&1) > 0))

    put_in(path.operation.tags, tags)
  end
  def ensure_tag(path, _module), do: path

  @doc false
  # Allow the verb and path to be inferred from the phoenix route
  def ensure_verb_and_path(path = %PathObject{verb: nil, path: nil}, route) do
    %{path | verb: route.verb, path: route.path}
  end
  def ensure_verb_and_path(path, _route), do: path

  @doc """
  Use JSON library from phoenix configuration
  """
  def json_library do
    Application.get_env(:phoenix_swagger, :json_library, Poison)
  end

  @doc false
  # Converts a Schema struct to regular map, removing nils
  def to_json(value = %{__struct__: _}) do
    value
    |> Map.from_struct()
    |> to_json()
  end
  def to_json(value) when is_map(value) do
    value
    |> Enum.map(fn {k,v} -> {to_string(k), to_json(v)} end)
    |> Enum.filter(fn {_, :null} -> false; _ -> true end)
    |> Enum.into(%{})
  end
  def to_json(value) when is_list(value) do
    Enum.map(value, &to_json/1)
  end
  def to_json(nil) do :null end
  def to_json(:null) do :null end
  def to_json(true) do true end
  def to_json(false) do false end
  def to_json(value) when is_atom(value) do to_string(value) end
  def to_json(value) do value end
end
