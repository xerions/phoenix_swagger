defmodule PhoenixSwagger do

  use Application

  @shortdoc "Generate swagger_[action] function for a phoenix controller"

  @moduledoc """
  The PhoenixSwagger module provides swagger_model/2 macro that akes two
  arguments:

    * `action` - name of the controller action (:index, ...);
    * `expr`   - do block that contains swagger definitions.

  Example:

      swagger_model :index do
        description "Short description"
        parameter :path, :id, :number, :required, "property id"
        responses 200, "Description", schema
      end

  Where the `schema` is a map that contains swagger response schema
  or a function that returns map.
  """

  @table :validator_table
  @swagger_data_types [:integer, :long, :float, :double, :string,
                       :byte, :binary, :boolean, :date, :dateTime,
                       :password]

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
      alias PhoenixSwagger.Schema
    end
  end

  defmacro swagger_model(action, expr) do
    metadata = unblock(expr)
    description = Keyword.get(metadata, :description)
    tags = Keyword.get(metadata, :tags, get_tags_module(__CALLER__))
    parameters = get_parameters(metadata)
    fun_name = ("swagger_" <> to_string(action)) |> String.to_atom
    [response_code, response_description | meta] = Keyword.get(metadata, :responses)

    quote do
      def unquote(fun_name)() do
        {PhoenixSwagger.get_description(__MODULE__, unquote(description)),
         unquote(parameters),
         unquote(tags),
         unquote(response_code),
         unquote(response_description),
         unquote(meta)}
      end
    end
  end

  defp get_tags_module(caller) do
    caller.module
    |> Module.split
    |> Enum.reverse
    |> hd
    |> String.split("Controller")
    |> Enum.filter(&(String.length(&1) > 0))
  end

  @doc false
  defp get_parameters(parameters) do
    Enum.map(parameters,
      fn(metadata) ->
        case metadata do
          {:parameter, [:body, name, schema, :required, description]} ->
            {:param, [in: :body, name: name, schema: schema, required: true, description: description]}
          {:parameter, [:body, name, schema, :required]} ->
            {:param, [in: :body, name: name, schema: schema, required: true, description: ""]}
          {:parameter, [:body, name, schema, description]} ->
            {:param, [in: :body, name: name, schema: schema, required: false, description: description]}
          {:parameter, [:body, name, schema]} ->
            {:param, [in: :body, name: name, schema: schema, required: false, description: ""]}
          {:parameter, [path, name, type, :required, description]} ->
            {:param, [in: path, name: name, type: valid_type?(type), required: true, description: description]}
          {:parameter, [path, name, type, :required]} ->
            {:param, [in: path, name: name, type: valid_type?(type), required: true, description: ""]}
          {:parameter, [path, name, type, description]} ->
            {:param, [in: path, name: name, type: valid_type?(type), required: false, description: description]}
          {:parameter, [path, name, type]} ->
            {:param, [in: path, name: name, type: valid_type?(type), required: false, description: ""]}
          _ ->
            []
        end
      end) |> List.flatten
  end

  @doc false
  defp valid_type?(type) do
    if not (type in @swagger_data_types) do
      raise "Error: write datatype: #{type}"
    else
      type
    end
  end

  @doc false
  defp unblock([do: {:__block__, _, body}]) do
    Enum.map(body, fn({name, _line, params}) -> {name, params} end)
  end

  @doc false
  def get_description(_, description) when is_list(description) do
    description
  end

  def get_description(module, description) when is_function(description) do
    module.description()
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
  defmacro swagger_schema([do: {:__block__, _, exprs}]) do
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
