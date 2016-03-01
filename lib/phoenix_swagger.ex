defmodule PhoenixSwagger do

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

  @swagger_data_types [:integer, :long, :float, :double, :string,
                       :byte, :binary, :boolean, :date, :dateTime,
                       :password]

  defmacro __using__(_) do
    quote do
      import PhoenixSwagger
    end
  end

  defmacro swagger_model(action, expr) do
    metadata = unblock(expr)
    description = Keyword.get(metadata, :description)

    tags = get_tags_module(__CALLER__)
    tags = Keyword.get(metadata, :tags, tags)

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
      end) |> :lists.flatten
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

end
