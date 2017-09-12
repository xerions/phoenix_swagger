defmodule PhoenixSwagger.Plug.Validate do
  import Plug.Conn
  alias PhoenixSwagger.Validator

  @table :validator_table

  @doc """
  Plug.init callback

  Options:

   - `:validation_failed_status` the response status to set when parameter validation fails, defaults to 400.
   - `:exclude_paths` paths matching these regular expressions will be excluded from validation
  """
  def init(opts), do: opts

  def call(conn, opts) do
    regex_result = opts
    |> Keyword.get(:exclude_paths, [~r/$^/]) # the default regex matches nothing
    |> List.wrap
    |> Enum.find(:no_regex_matched, fn r -> Regex.match?(r, conn.request_path) end)

    case regex_result do
      :no_regex_matched ->
        handle_validation(conn, opts)
      _ ->
        conn
    end
  end

  @doc """
  Performs unconditional validation of a request. Will halt and send error on failed validation.
  """
  def handle_validation(conn, opts) do
    validation_failed_status = Keyword.get(opts, :validation_failed_status, 400)

    case validate(conn) do
      {:ok, conn} ->
        conn
      {:error, :no_matching_path} ->
        send_error_response(conn, 404, "API does not provide resource", conn.request_path)
      {:error, message, path} ->
        send_error_response(conn, validation_failed_status, message, path)
    end
  end

  @doc """
  Validate a request. Feel free to use it in your own Plugs. Returns:
  * `{:ok, conn}` on success
  * `{:error, :no_matching_path}` if the request path could not be mapped to a schema
  * `{:error, message, path}` if the request was mapped but failed validation
  """
  def validate(conn) do
    result =
      with {:ok, path} <- find_matching_path(conn),
           :ok <- validate_body_params(path, conn),
           :ok <- validate_query_params(path, conn),
           do: {:ok, conn}

  end

  defp find_matching_path(conn) do
    found = Enum.find(:ets.tab2list(@table), fn({path, base_path, _}) ->
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

  defp send_error_response(conn, status, message, path) do
    response = %{
      error: %{
        path: path,
        message: message
      }
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(response))
    |> halt()
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

  defp validate_query_params([]), do: :ok
  defp validate_query_params([{_type, _name, nil, false} | parameters]) do
    validate_query_params(parameters)
  end
  defp validate_query_params([{_type, name, nil, true} | _]) do
    {:error, "Required property #{name} was not present.", "#"}
  end
  defp validate_query_params([{"string", _name, _val, _} | parameters]) do
    validate_query_params(parameters)
  end
  defp validate_query_params([{"integer", name, val, _} | parameters]) do
    validate_integer(name, val, parameters)
  end
  defp validate_query_params([{"boolean", name, val, _} | parameters]) do
    validate_boolean(name, val, parameters)
  end
  defp validate_query_params(path, conn) do
    [{_path, _basePath, schema}] = :ets.lookup(@table, path)
    parameters =
      for parameter <- schema.schema["parameters"],
          parameter["type"] != nil,
          parameter["in"] in ["query", "path"] do
        {parameter["type"], parameter["name"], get_param_value(conn.params, parameter["name"]), parameter["required"]}
      end
    validate_query_params(parameters)
  end

  defp get_in_nested(params = nil, _), do: params
  defp get_in_nested(params, nil), do: params
  defp get_in_nested(params, nested_map) when map_size(nested_map) == 1 do
    [{key, child_nested_map}] = Map.to_list(nested_map)

    get_in_nested(params[key], child_nested_map)
  end

  defp get_param_value(params, nested_name) when is_binary(nested_name) do
    nested_map = Plug.Conn.Query.decode(nested_name)
    get_in_nested(params, nested_map)
  end

  defp validate_body_params(path, conn) do
    case Validator.validate(path, conn.body_params) do
      :ok -> :ok
      {:error, [{error, error_path} | _], _path} -> {:error, error, error_path}
      {:error, error, error_path} ->  {:error, error, error_path}
    end
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
