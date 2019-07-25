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
    schemas = Enum.map(specs, fn (spec) ->
      read_swagger_schema(spec)
    end)
    schema = Enum.reduce(schemas, %{}, fn(schema, acc) ->
      acc = if acc["paths"] == nil do
              Map.merge(acc, schema)
            else
              acc = Map.update!(acc, "paths", fn(paths_map) -> Map.merge(paths_map, schema["paths"]) end)
              Map.update!(acc, "definitions", fn(definitions_map) -> Map.merge(definitions_map, schema["definitions"]) end)
            end
      acc
    end)
    collect_schema_attrs(schema)
  end
  def parse_swagger_schema(spec) do
    schema = read_swagger_schema(spec)
    collect_schema_attrs(schema)
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
      Enum.map(Map.keys(data), fn(method) ->
        parameters = data[method]["parameters"]
        # we may have a request without parameters, so nothing to validate
        # in this case
        if parameters == nil do
          []
        else
          # Let's go through requests parameters from swagger schema
          # and collect it into json schema properties.
          properties = Enum.reduce(parameters, %{}, fn(parameter, acc) ->
            acc = if parameter["type"] == nil do
                    ref = String.split(parameter["schema"]["$ref"], "/") |> List.last
                    Map.merge(acc, schema["definitions"][ref])
                  else
                    acc
                  end
            acc
          end)
          # collect request primitive parameters which do not refer to `definitions`
          # these are mostly parameters from query string
          properties = Enum.reduce(parameters, properties, fn(parameter, acc) ->
            if parameter["type"] != nil do
              collect_properties(acc, parameter)
            else
              acc
            end
          end)
          # actually all requests which have parameters are objects
          properties = if properties["type"] == nil do
                         Map.put_new(properties, "type", "object")
                       else
                         properties
                       end
          # store path concatenated with method. This allows us
          # to identify the same resources with different http methods.
          path = "/" <> method <> path
          schema_object = Map.merge(%{"parameters" => parameters, "type" => "object", "definitions" => schema["definitions"]}, properties)
          resolved_schema = ExJsonSchema.Schema.resolve(schema_object)
          :ets.insert(@table, {path, schema["basePath"], resolved_schema})
          {path, resolved_schema}
        end
      end)
    end) |> List.flatten
  end

  @doc false
  defp collect_properties(properties, parameter) when properties == %{} do
    Map.put(%{}, "properties", Map.put_new(%{}, parameter["name"], %{"type" => parameter["type"]}))
  end
  defp collect_properties(properties, parameter) do
    props = Map.put(properties["properties"], parameter["name"], %{"type" => parameter["type"]})
    Map.put(properties, "properties", props)
  end

  @doc false
  defp read_swagger_schema(file) do
    schema = File.read(file) |> elem(1) |> PhoenixSwagger.json_library().decode() |> elem(1)
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
