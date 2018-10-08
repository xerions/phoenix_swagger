defmodule PhoenixSwagger.Validator do

  @moduledoc """
  The PhoenixSwagger.Validator module provides converter of
  swagger schema to ex_json_schema structure for further validation.

  There are two main functions:

    * parse_swagger_schema/1
    * validate/2

  Before `validate/2` will be called, a swagger schema should be parsed
  for futher validation with the `parse_swagger_schema/1`. This function
  takes path to a swagger schema and returns it in ex_json_schema format.

  During execution of the `parse_swagger_schema/1` function, it creates
  the `validator_table` ets table and stores associative key/value there.
  Where `key` is an API path of a resource and `value` is input parameters
  of a resource.

  To validate of a parsed swagger schema, the `validate/1` should be used.

  For more information, see more in ./phoenix_swagger/tests/ directory.
  """

  @table :validator_table

  @doc """
  The `parse_swagger_schema/1` takes path or list of paths to a swagger schema(s), 
  parses it/them into ex_json_schema format and store to the `validator_table` ets
  table.

  Usage:

      iex(1)> parse_swagger_schema("my_json_spec.json")
      [{"/person",  %{'__struct__' => 'Elixir.ExJsonSchema.Schema.Root',
                      location => root,
                      refs => %{},
                      schema => %{
                        "properties" => %{
                          "name" => %{"type" => "string"},
                          "age" => %{"type" => "integer"}
                        }
                      }
                    }
      }]

  """
  def parse_swagger_schema(specs) when is_list(specs) do
    specs
    |> Enum.map(&read_swagger_schema/1)
    Enum.reduce(%{}, fn(schema, acc) ->
      if acc["paths"] == nil do
        Map.merge(acc, schema)
      else
        acc
        |> Map.update!("paths", fn(paths_map) -> Map.merge(paths_map, schema["paths"]) end)
        |> Map.update!("definitions", fn(definitions_map) -> Map.merge(definitions_map, schema["definitions"]) end)
      end
    end)
    |> collect_schema_attrs()
  end
  def parse_swagger_schema(spec) do
    spec
    |> read_swagger_schema()
    |> collect_schema_attrs()
  end

  @doc """
  The `validate/2` takes a resource path and input parameters
  of this resource.

  Returns `:ok` in a case when parameters are valid for the
  given resource or:

    * {:error, :resource_not_exists} in a case when path is not
      exists in the validator table;
    * {:error, error_message, path} in a case when at least
      one  parameter is not valid for the given resource.
  """
  def validate(path, params) do
    case :ets.lookup(@table, path) do
      [] ->
        {:error, :resource_not_exists}
      [{_, _, schema}] ->
        case ExJsonSchema.Validator.validate(schema, params) do
          :ok ->
            :ok
          {:error, [{error, path}]} ->
            {:error, error, path}
          {:error, error} ->
            {:error, error, path}
        end
    end
  end

  @doc false
  defp collect_schema_attrs(schema) do
    Enum.map(schema["paths"], fn({path, data}) ->
      data
      |> Enum.map(fn {method, path_item} ->
        {required, properties} =
        (path_item["parameters"] || [])
        |> Enum.reduce({[], %{}}, fn param = %{"name" => name}, {required, properties} ->
          # Let's go through requests parameters from swagger schema
          # and collect it into json schema properties.
          properties =
            case param do
              %{"type" => type} ->
                properties |> Map.put_new(name, %{"type" => type})
              %{"schema" => %{"$ref" => "#/definitions/"<>ref}} ->
                properties |> Map.put_new(name, schema["definitions"][ref])
              %{"schema" => param_schema} ->
                properties |> Map.put_new(name, param_schema)
            end
          if param["required"] do
            {[name | required], properties}
          else
            {required, properties}
          end
        end)

        # actually all requests which have parameters are objects
        resolved_schema = %{
          "type" => "object",
          "required" => required,
          "properties" => properties,
          "parameters" => path_item["parameters"] || [],
          "definitions" => schema["definitions"] || %{}
        }
        |> ExJsonSchema.Schema.resolve()
        # store path concatenated with method. This allows us
        # to identify the same resources with different http methods.
        key = "/" <> method <> path
        :ets.insert(@table, {key, schema["basePath"], resolved_schema})
        {key, resolved_schema}
      end)
    end) |> List.flatten
  end

  @doc false
  defp read_swagger_schema(file) do
    schema = File.read(file) |> elem(1) |> Poison.decode() |> elem(1)
    # get rid from all keys besides 'paths' and 'definitions' as we
    # need only in these fields for validation
    Enum.reduce(schema, %{}, fn(map, acc) ->
      {key, val} = map
      if key in ["basePath", "paths", "definitions"] do
        Map.put_new(acc, key, val)
      else
        acc
      end
    end)
  end
end
