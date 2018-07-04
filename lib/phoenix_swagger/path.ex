defmodule PhoenixSwagger.Path do
  @moduledoc """
  Defines the swagger path DSL for specifying Controller actions.
  This module should not be imported directly, it will be automatically imported
  in the scope of a `swagger_path` macro body.

  ## Examples

      use PhoenixSwagger

      swagger_path :index do
        get "/users"
        produces "application/json"
        paging
        parameter :id, :query, :integer, "user id", required: true
        tag "Users"
        response 200 "User resource" :User
        response 404 "User not found"
      end
  """

  alias PhoenixSwagger.Schema

  defmodule Parameter do
    @moduledoc """
    A swagger parameter definition, similar to a `Schema`, but swagger defines
    parameter name (and some other options) to be part of the parameter object itself.
    See http://swagger.io/specification/#parameterObject
    """

    defstruct(
      name: "",
      in: "",
      description: "",
      required: false,
      schema: nil,
      type: nil,
      format: nil,
      allowEmptyValue: nil,
      items: nil,
      collectionFormat: nil,
      default: nil,
      maximum: nil,
      exclusiveMaximum: nil,
      minimum: nil,
      exclusiveMinimum: nil,
      maxLength: nil,
      minLength: nil,
      pattern: nil,
      maxItems: nil,
      minItems: nil,
      uniqueItems: nil,
      enum: nil,
      multipleOf: nil)
  end

  defmodule ResponseObject do
    @moduledoc """
    A swagger response definition.
    The response status (200, 404, etc.) is the key in the containing map.
    See http://swagger.io/specification/#responseObject
    """
    defstruct description: "", schema: nil, headers: nil, examples: nil
  end

  defmodule OperationObject do
    @moduledoc """
    A swagger operation object ties together parameters, responses, etc.
    See http://swagger.io/specification/#operationObject
    """
    defstruct(
      tags: [],
      summary: "",
      description: "",
      externalDocs: nil,
      operationId: "",
      consumes: nil,
      produces: nil,
      parameters: [],
      responses: %{},
      deprecated: nil,
      security: nil)
  end

  defmodule PathObject do
    @moduledoc """
    The DSL builds paths out of individual operations, so this is a flattened version
    of a swagger Path. The `nest` function will convert this to a nested map before final
    conversion to a JSON map.
    See http://swagger.io/specification/#pathsObject
    """
    defstruct path: nil, verb: nil, operation: %OperationObject{}
  end

  @doc "Initializes a PathObject with verb \"get\" and given path"
  def get(path_obj = %PathObject{}, path), do: %{path_obj | path: path, verb: "get"}

  @doc "Initializes a PathObject with verb \"post\" and given path"
  def post(path_obj = %PathObject{}, path), do: %{path_obj | path: path, verb: "post"}

  @doc "Initializes a PathObject with verb \"put\" and given path"
  def put(path_obj = %PathObject{}, path), do: %{path_obj | path: path, verb: "put"}

  @doc "Initializes a PathObject with verb \"patch\" and given path"
  def patch(path_obj = %PathObject{}, path), do: %{path_obj | path: path, verb: "patch"}

  @doc "Initializes a PathObject with verb \"delete\" and given path"
  def delete(path_obj = %PathObject{}, path), do: %{path_obj | path: path, verb: "delete"}

  @doc "Initializes a PathObject with verb \"head\" and given path"
  def head(path_obj = %PathObject{}, path), do: %{path_obj | path: path, verb: "head"}

  @doc "Initializes a PathObject with verb \"options\" and given path"
  def options(path_obj = %PathObject{}, path), do: %{path_obj | path: path, verb: "options"}

  @doc """
  Adds the summary section to the operation of a swagger `%PathObject{}`
  """
  def summary(path = %PathObject{}, summary) do
    put_in path.operation.summary, summary
  end

  @doc """
  Adds the description section to the operation of a swagger `%PathObject{}`
  """
  def description(path = %PathObject{}, description) do
    put_in path.operation.description, description
  end

  @doc """
  Adds a mime-type to the consumes list of the operation of a swagger `%PathObject{}`
  """
  def consumes(path = %PathObject{}, mimetype) do
    put_in path.operation.consumes, (path.operation.consumes || []) ++ [mimetype]
  end

  @doc """
  Adds a mime-type to the produces list of the operation of a swagger `%PathObject{}`
  """
  def produces(path = %PathObject{}, mimetype) do
    put_in path.operation.produces, (path.operation.produces || []) ++ [mimetype]
  end

  @doc """
  Adds a tag to the operation of a swagger `%PathObject{}`
  """
  def tag(path = %PathObject{}, tag) do
    put_in path.operation.tags, path.operation.tags ++ [tag]
  end

  @doc """
  Adds the operationId section to the operation of a swagger `%PathObject{}`
  """
  def operation_id(path = %PathObject{}, id) do
    put_in path.operation.operationId, id
  end

  @doc """
  Adds the security section to the operation of a swagger `%PathObject{}`
  """
  def security(path = %PathObject{}, security) do
    put_in path.operation.security, security
  end

  @doc """
  Defines multiple parameters for an operation with a custom DSL syntax

  ## Example

      swagger_path :create do
        post "/api/v1/{team}/users"
        summary "Create a new user"
        parameters do
          user :body, Schema.ref(:User), "user attributes"
          team :path, :string, "Users team ID"
        end
        response 200, "OK", :User
      end
  """
  defmacro parameters(path, block) do
    exprs = case block do
      [do: {:__block__, _, exprs}] -> exprs
      [do: expr] -> [expr]
    end

    exprs
    |> Enum.map(fn {name, line, args} -> {:parameter, line, [name | args]} end)
    |> Enum.reduce(path, fn expr, acc ->
         quote do unquote(acc) |> unquote(expr) end
       end)
  end

  @doc """
  Adds a parameter to the operation of a swagger `%PathObject{}`
  """
  def parameter(path = %PathObject{}, name, location, type, description, opts \\ []) do
    param = %Parameter{
      name: name,
      in: location,
      description: description
    }
    param = case location do
      :body -> %{param | schema: type}
      :path -> %{param | type: type, required: true}
      _ -> %{param | type: type}
    end
    param = Map.merge(param, opts |> Enum.into(%{}, &translate_parameter_opt/1))
    params = path.operation.parameters
    put_in path.operation.parameters, params ++ [param]
  end

  @doc """
  Adds the deprecation section to the operation of a swagger `%PathObject{}`
  """
  def deprecated(path = %PathObject{}, status) do
    put_in path.operation.deprecated, status
  end

  defp translate_parameter_opt({:example, v}), do: {:"x-example", v}
  defp translate_parameter_opt({:items, items_schema}) when is_list(items_schema) do
     {:items, Enum.into(items_schema, %{})}
  end
  defp translate_parameter_opt({k, v}), do: {k, v}

  @doc """
  Adds page size, number and offset parameters to the operation of a swagger `%PathObject{}`

  The names default to  "page_size" and "page" for ease of use with `scriviner_ecto`, but can be overridden.

  ## Examples

      get "/api/pets/"
      paging
      response 200, "OK"

      get "/api/pets/dogs"
      paging size: "page_size", number: "count"
      response 200, "OK"

      get "/api/pets/cats"
      paging size: "limit", offset: "offset"
      response 200, "OK"
  """
  def paging(path = %PathObject{}, opts \\ [size: "page_size", number: "page"]) do
    Enum.reduce opts, path, fn
      {:size, size}, path -> parameter(path, size, :query, :integer, "Number of elements per page", minimum: 1)
      {:number, number}, path -> parameter(path, number, :query, :integer, "Number of the page", minimum: 1)
      {:offset, offset}, path -> parameter(path, offset, :query, :integer, "Offset of first element in the page")
    end
  end

  @doc """
  Adds a response to the operation of a swagger `%PathObject{}`, without a schema
  """
  def response(path = %PathObject{}, status, description) do
    resp = %ResponseObject{description: description}
    put_in path.operation.responses[to_string(status)], resp
  end

  @doc """
  Adds a response to the operation of a swagger `%PathObject{}`, with a schema

  Optional keyword args can be provided for `headers` and `examples`
  If the mime-type is known from the `produces` list, then a single can be given as a shorthand.

  ## Example

      get "/users/{id}"
      produces "application/json"
      parameter :id, :path, :integer, "user id", required: true
      response 200, "Success", :User, examples: %{"application/json": %{id: 1, name: "Joe"}}

      get "/users/{id}"
      produces "application/json"
      parameter :id, :path, :integer, "user id", required: true
      response 200, "Success", :User, example: %{id: 1, name: "Joe"}
  """
  def response(path, status, description, schema, opts \\ [])
  def response(path = %PathObject{}, status, description, schema, opts) when is_atom(schema)  do
    response(path, status, description, Schema.ref(schema), opts)
  end
  def response(path = %PathObject{}, status, description, schema = %{}, opts) do
    opts = expand_response_example(path, opts)
    resp = struct(ResponseObject, [description: description, schema: schema] ++ opts)
    put_in path.operation.responses[status |> to_string], resp
  end

  def expand_response_example(%PathObject{operation: %{produces: [mimetype | _]}}, opts) do
    Enum.map(opts, fn
      {:example, e} -> {:examples, %{mimetype => e}}
      opt -> opt
    end)
  end
  def expand_response_example(%PathObject{}, opts), do: opts

  @doc """
  Converts the `%PathObject{}` struct into the nested JSON form expected by swagger
  """
  def nest(path = %PathObject{}) do
    %{path.path => %{path.verb => path.operation}}
  end
end
