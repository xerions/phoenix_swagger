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
      [{_, schema}] ->
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
          # Let's go through requests parameters from swagger scheme
          # and collect it into json schema properties.
          properties = Enum.reduce(parameters, %{}, fn(parameter, acc) ->
            Map.merge(acc, get_property_type(schema, parameter, "", acc))
          end)
          # store path concatenated with method. This allows us
          # to identify the same resources with different http methods.
          path = "/" <> method <> path
          # collect required feilds
          required = Enum.map(parameters, fn(parameter) ->
            if parameter["schema"] != nil do
              {parameter, parameter["required"] == true}
            else
              if parameter["required"] == true do
                parameter["name"]
              else
                false
              end
            end
          end)
          required = Enum.map(required, fn(property) ->
            case property do
              false ->
                []
              {_, true} ->
                Enum.reduce(properties, [], fn({property, _property_opts}, acc) ->
                  [property | acc]
                end)
              _ ->
                property
            end
          end) |> List.flatten |> Enum.uniq
          schema_object = if length(required) == 0 do
                            %{"type" => "object", "properties" => properties, "definitions" => schema["definitions"]}
                          else
                            %{"type" => "object", "properties" => properties, "definitions" => schema["definitions"], "required" => required}
                          end
          :ets.insert(@table, {path, ExJsonSchema.Schema.resolve(schema_object)})
          {path, ExJsonSchema.Schema.resolve(schema_object)}
        end
      end)
    end) |> List.flatten
  end

  @doc false
  defp get_property_type(schema, parameter, property_name, acc) do
    {properties, has_properties?} = get_properties(schema, parameter, parameter["schema"] || parameter)
    if has_properties? do
      collect_properties(schema, parameter, properties, property_name)
    else
      Map.put_new(acc || %{}, parameter["name"], %{"type" => parameter["type"]})
    end
  end

  @doc false
  defp get_properties(schema, parameter, ref) do
    if ref["$ref"] != nil do
      [_, definition, path] = String.split(ref["$ref"], "/")
      props = schema[definition][path]["properties"] 
      {props, props != nil}
    else
      if parameter["properties"] != nil do
        {parameter["properties"], true}
      else
        props = parameter["schema"]["properties"]
        {props, props != nil}
      end
    end
  end

  @doc false
  defp collect_properties(schema, parameter, properties, property_name) do
    Enum.reduce(properties, %{}, fn({property, type}, ref_acc) ->
      if type["$ref"] != nil do
        [_, definition, path] = String.split(type["$ref"], "/")
        type = schema[definition][path]["type"]
        if type == "object" or type == "array" do
          Map.put_new(ref_acc, path, %{"type" => type, "$ref" => "#/definitions/" <> path})
        else
          Map.put_new(ref_acc, property, %{"type" => schema[definition][path]["type"]})
        end
      else
        if ref_acc[parameter["name"]] == nil do
          if parameter["name"] == nil do
            map = Map.put_new(%{}, property, %{"type" => type["type"]})
            ref_acc = if ref_acc[property_name] == nil do
                        Map.put_new(ref_acc, property_name, map)
                      else
                        Map.put(ref_acc, property_name, Map.merge(ref_acc[property_name] || %{}, map))
                      end
            ref_acc
          else
            ref_acc = Map.put_new(ref_acc, property, %{"type" => type["type"]})
            ref_acc
          end
        else
          map = Map.put_new(ref_acc[parameter["name"]], property, %{"type" => type["type"]})
          ref_acc = Map.delete(ref_acc, parameter["name"])
          |> Map.put_new(parameter["name"], map)
        end
      end
    end)
  end

  @doc false
  defp read_swagger_schema(file) do
    schema = File.read(file) |> elem(1) |> Poison.decode() |> elem(1)
    # get rid from all keys besides 'paths' and 'definitions' as we
    # need only in these fields for validation
    Enum.reduce(schema, %{}, fn(map, acc) ->
      {key, val} = map
      if key in ["paths", "definitions"] do
        Map.put_new(acc, key, val)
      else
        acc
      end
    end)
  end
end
