defmodule PhoenixSwagger.Plug.Validate do
  import Plug.Conn
  alias PhoenixSwagger.Validator

  @table :validator_table

  def init(opts), do: opts

  def call(conn, _data) do
    req_path = Enum.filter(:ets.tab2list(@table), fn({path, _}) ->
      equal_paths(path, String.split(path, "/") |> tl, conn.path_info |> tl) != []
    end)
    case req_path do
      [] -> conn
      [{path, _}] ->
        case Validator.validate(path, conn.params) do
          :ok -> conn
          {:error, error, path} ->
            send_resp(conn, 400, %{"error" => %{"message" => error, "path" => path}} |> Poison.encode |> elem(1))
            |> halt()
        end
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
