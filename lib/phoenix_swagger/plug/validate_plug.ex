defmodule PhoenixSwagger.Plug.Validate do
  import Plug.Conn
  alias PhoenixSwagger.Validator

  @table :validator_table

  def init(opts), do: opts

  def call(conn, _data) do
    req_path = Enum.filter(:ets.tab2list(@table), fn({path, _}) ->
      req_path = ("/" <> String.downcase(conn.method) <> "/" <> Enum.join(conn.path_info |> tl, "/"))
                 |> String.split("/")
                 |> tl
      equal_paths(path, String.split(path, "/") |> tl, req_path) != []
    end)
    case req_path do
      [] ->
        response = %{"error" => %{"message" => "API does not provide resource",
                                  "path" => "/" <> (conn.path_info |> Enum.join("/"))}}
        send_resp(conn, 404, response)
        |> halt()
      [{path, _}] ->
        case {validate_body_params(path, conn.params),
              validate_query_params(path, conn.params)} do
          {:ok, :ok} ->
            conn
          {{:error, error, path}, _} ->
            response = %{"error" => %{"message" => error,
                                      "path" => path}} |> Poison.encode |> elem(1)
            send_resp(conn, 400, response)
            |> halt()
          {_, {:error, error, path}} ->
            case is_list(error) do
              true -> Enum.into(error, %{})
              _ -> error
            end
            response = %{"error" =>%{"message" => error,
                                     "path" => path}} |> Poison.encode |> elem(1)
            send_resp(conn, 400, response)
            |> halt()
        end
    end
  end

  defp validate_integer(name, value, parameters) do
    try do
      _ = String.to_integer(value)
      validate_query_params(parameters)
    rescue _e in ArgumentError ->
        {:error, "Type mismatch. Expected Integer but got String.", "#/#{name}"}
    end
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
  defp validate_query_params(path, params) do
    [{_, schema}] = :ets.lookup(@table, path)
    parameters = Enum.map(schema.schema["parameters"], fn parameter ->
      if parameter["type"] != nil and parameter["in"] == "query" do
        {parameter["type"], parameter["name"], params[parameter["name"]], parameter["required"]}
      else
        []
      end
    end) |> List.flatten
    validate_query_params(parameters)
  end

  defp validate_body_params(path, params) do
    [{_, schema}] = :ets.lookup(@table, path)
    parameters = Enum.map(schema.schema["parameters"], fn parameter ->
      if parameter["type"] != nil and parameter["in"] == "query" do
        parameter["name"]
      else
        []
      end
    end) |> List.flatten
    if parameters == [] do
      Validator.validate(path, params)
    else
      params = Enum.filter(params, fn ({name, _val}) ->
        not name in parameters
      end) |> Enum.into(%{})
      Validator.validate(path, params)
    end
  end

  defp equal_paths(_, [], req) when length(req) > 0, do: []
  defp equal_paths(_, orig, []) when length(orig) > 0, do: []
  defp equal_paths(orig_path, [], []), do: orig_path
  defp equal_paths(orig_path, [orig | orig_path_rest], [ req | req_path_rest]) do
    if (String.codepoints(orig) |> hd) == "{" or orig == req do
      equal_paths(orig_path, orig_path_rest, req_path_rest)
    else
      []
    end
  end
end
