defmodule PhoenixSwagger.ConnValidator do
  alias PhoenixSwagger.Validator

  @table :validator_table

  @doc """
  Validate a request. Feel free to use it in your own Plugs. Returns:
  * `{:ok, conn}` on success
  * `{:error, :no_matching_path}` if the request path could not be mapped to a schema
  * `{:error, message, path}` if the request was mapped but failed validation
  * `{:error, [{message, path}], path}` if more than one validation error has been detected
  """
  def validate(conn) do
    with {:ok, path} <- find_matching_path(conn),
          :ok <- validate_body_params(path, conn),
          :ok <- validate_query_params(path, conn),
          do: {:ok, conn}
  end

  defp find_matching_path(conn) do
    found =
      :ets.tab2list(@table)
      |> Enum.sort()
      |> Enum.find(fn({path, base_path, _}) ->
      base_path_segments = String.split(base_path || "", "/") |> tl
      path_segments = String.split(path, "/") |> tl
      path_info_without_base = remove_base_path(conn.path_info, base_path_segments)
      req_path_segments = [String.downcase(conn.method) | path_info_without_base]
      equal_paths?(path_segments, req_path_segments)
    end)

    case found do
      nil -> {:error, :no_matching_path}
      {path, _, _} -> {:ok, path}
    end
  end

  defp validate_array(name, values, items=%{"type"=>type}, parameters) do
    with :ok <- String.split(values, ",")
                |> Enum.map(&{type, name, &1, false, Map.get(items, "enum"), nil})
                |> validate_query_params()
    do validate_query_params(parameters)
    else
      error -> error
    end
  end

  defp validate_enum(name, value, enum, parameters) do
    cond do
      value in enum -> validate_query_params(parameters)
      true -> {:error, "Value #{inspect(value)} is not allowed in enum.", "#/#{name}"}
    end
  end

  defp validate_boolean(_name, value, parameters) when value in ["true", "false"] do
    validate_query_params(parameters)
  end
  defp validate_boolean(name, _value, _parameters) do
    {:error, "Type mismatch. Expected Boolean but got String.", "#/#{name}"}
  end

  defp validate_integer(name, value, parameters) do
    _ = String.to_integer(value)
    validate_query_params(parameters)
  rescue ArgumentError ->
      {:error, "Type mismatch. Expected Integer but got String.", "#/#{name}"}
  end

  defp validate_number(name, value, parameters) do
    {_, ""} = Float.parse(value)
    validate_query_params(parameters)
  rescue MatchError ->
      {:error, "Type mismatch. Expected Number but got String.", "#/#{name}"}
  end

  defp validate_query_params([]), do: :ok
  defp validate_query_params([{_type, _name, nil, false, _, _} | parameters]) do
    validate_query_params(parameters)
  end
  defp validate_query_params([{_type, name, nil, true, _, _} | _]) do
    {:error, "Required property #{name} was not present.", "#"}
  end
  defp validate_query_params([{_type, name, val, _, enum, _} | parameters]) when not is_nil(enum) do
    validate_enum(name, val, enum, parameters)
  end
  defp validate_query_params([{"string", _name, _val, _, _, _} | parameters]) do
    validate_query_params(parameters)
  end
  defp validate_query_params([{"integer", name, val, _, _, _} | parameters]) do
    validate_integer(name, val, parameters)
  end
  defp validate_query_params([{"number", name, val, _, _, _} | parameters]) do
    validate_number(name, val, parameters)
  end
  defp validate_query_params([{"boolean", name, val, _, _, _} | parameters]) do
    validate_boolean(name, val, parameters)
  end
  defp validate_query_params([{"array", name, vals, _, _, items} | parameters]) do
    validate_array(name, vals, items, parameters)
  end
  defp validate_query_params(path, conn) do
    [{_path, _basePath, schema}] = :ets.lookup(@table, path)
    parameters =
      for parameter <- schema.schema["parameters"],
          parameter["type"] != nil,
          parameter["in"] in ["query", "path"] do
              {parameter["type"], parameter["name"], get_param_value(conn.params, parameter["name"]),
                           parameter["required"], parameter["enum"], parameter["items"]}
      end
    validate_query_params(parameters)
  end

  defp get_in_nested(params = nil, _), do: params
  defp get_in_nested(params, nil), do: params
  defp get_in_nested(params, ""), do: params
  defp get_in_nested(params, nested_map) when map_size(nested_map) == 1 do
    [{key, child_nested_map}] = Map.to_list(nested_map)

    get_in_nested(params[key], child_nested_map)
  end

  defp get_param_value(params, nested_name) when is_binary(nested_name) do
    nested_map = Plug.Conn.Query.decode(nested_name)
    get_in_nested(params, nested_map)
  end

  defp validate_body_params(path, conn) do
    Validator.validate(path, conn.body_params)
  end

  defp equal_paths?([], []), do: true
  defp equal_paths?([head | orig_path_rest], [head | req_path_rest]), do: equal_paths?(orig_path_rest, req_path_rest)
  defp equal_paths?(["{" <> _ | orig_path_rest], [_ | req_path_rest]), do: equal_paths?(orig_path_rest, req_path_rest)
  defp equal_paths?(_, _), do: false

  # It is pretty safe to strip request path by base path. They can't be
  # non-equal. In this way, the router even will not execute this plug.
  defp remove_base_path(path, []), do: path
  defp remove_base_path([_path | rest], [_base_path | base_path_rest]) do
    remove_base_path(rest, base_path_rest)
  end
end
