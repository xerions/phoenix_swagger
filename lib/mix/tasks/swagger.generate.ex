defmodule Mix.Tasks.Phx.Swagger.Generate do
  use Mix.Task
  require Logger

  @recursive true

  @shortdoc "Generates swagger.json file based on phoenix router"

  @moduledoc """
  Generates swagger.json file based on phoenix router and controllers.

  Usage:

      mix phx.swagger.generate

      mix phx.swagger.generate ../swagger.json

      mix phx.swagger.generate ../swagger.json --router MyApp.Router
  """

  @default_title "<enter your title>"
  @default_version "0.0.1"

  defp app_path do
    Enum.at(Mix.Project.load_paths(), 0) |> String.split("_build") |> Enum.at(0)
  end
  defp top_level_namespace, do: Mix.Project.get().application()[:mod] |> elem(0) |> Module.split |> Enum.drop(-1) |> Module.concat
  defp app_name, do: Mix.Project.get().project()[:app]
  defp default_swagger_file_path, do: app_path() <> "swagger.json"
  defp default_router_module_name, do: Module.concat(["#{top_level_namespace()}Web", :Router])
  defp default_endpoint_module_name, do: Module.concat(["#{top_level_namespace()}Web", :Endpoint])
  defp router_module(switches), do: switches |> Keyword.get(:router, default_router_module_name()) |> attempt_load()
  defp endpoint_module(switches), do: switches |> Keyword.get(:endpoint, default_endpoint_module_name()) |> attempt_load()

  def run(args) do
    Mix.Task.run("compile")
    Mix.Task.reenable("phx.swagger.generate")
    Code.append_path("#{app_path()}_build/#{Mix.env}/lib/#{app_name()}/ebin")
    {switches, params, _unknown} = OptionParser.parse(
      args,
      switches: [router: :string, endpoint: :string, help: :boolean],
      aliases: [r: :router, e: :endpoint, h: :help])

    router = router_module(switches)
    endpoint = endpoint_module(switches)
    cond do
      (Keyword.get(switches, :help)) ->
        usage()
      is_nil(router) ->
        Logger.warn "Skipping app #{app_name()}, no Router configured."
      is_nil(endpoint) ->
        Logger.warn "Skipping app #{app_name()}, no Endpoint configured."
      true ->
        output_file = Enum.at(params, 0, default_swagger_file_path())
        write_file(output_file, swagger_document(router, endpoint))
        IO.puts "Generated #{output_file}"
    end
  end

  defp usage do
    IO.puts """
    Usage: mix phx.swagger.generate FILE --router ROUTER --endpoint ENDPOINT

    With no FILE, default swagger file #{default_swagger_file_path()}
    With no ROUTER, defaults to #{default_router_module_name()}
    With no ENDPOINT, defaults to #{default_endpoint_module_name()}
    """
  end


  defp write_file(output_file, contents) do
    directory = Path.dirname(output_file)
    unless File.exists?(directory) do
      File.mkdir_p!(directory)
    end
    File.write!(output_file, contents)
  end

  defp attempt_load(module_name) do
    case module_name |> List.wrap() |> Module.concat() |> Code.ensure_loaded() do
      {:module, result} -> result
      _ -> nil
    end
  end

  defp swagger_document(router, endpoint) do
    router
    |> collect_info()
    |> collect_host(endpoint)
    |> collect_paths(router)
    |> collect_definitions(router)
    |> Poison.encode!(pretty: true)
  end

  defp collect_info(router) do
    cond do
      function_exported?(router, :swagger_info, 0) ->
        Map.merge(default_swagger_info(), router.swagger_info())

      function_exported?(Mix.Project.get(), :swagger_info, 0) ->
        info =
          Mix.Project.get.swagger_info()
          |> Keyword.put_new(:title, @default_title)
          |> Keyword.put_new(:version, @default_version)
          |> Enum.into(%{})
        %{default_swagger_info() | info: info}

      true ->
        default_swagger_info()
    end
  end

  def default_swagger_info do
    %{
      swagger: "2.0",
      info: %{
        title: @default_title,
        version: @default_version,
      },
      paths: %{},
      definitions: %{}
    }
  end

  defp collect_paths(swagger_map, router) do
    router.__routes__()
    |> Enum.map(&find_swagger_path_function/1)
    |> Enum.filter(&!is_nil(&1))
    |> Enum.filter(&controller_function_exported?/1)
    |> Enum.map(&get_swagger_path/1)
    |> Enum.reduce(swagger_map, &merge_paths/2)
  end

  defp find_swagger_path_function(route = %{opts: action, path: path}) when is_atom(action) do
    controller = find_controller(route)
    swagger_fun = "swagger_path_#{action}" |> String.to_atom()

    cond do
      Code.ensure_loaded?(controller) ->
        %{
          controller: controller,
          swagger_fun: swagger_fun,
          path: format_path(path)
        }
      true ->
        Logger.warn "Warning: #{controller} module didn't load."
        nil
    end
  end
  defp find_swagger_path_function(_route) do
    # action not an atom usually means route to a plug which isn't a Phoenix controller
    nil
  end


  defp format_path(path) do
    Regex.replace(~r/:([^\/]+)/, path, "{\\1}")
  end

  defp controller_function_exported?(%{controller: controller, swagger_fun: fun}) do
    function_exported?(controller, fun, 0)
  end

  defp get_swagger_path(%{controller: controller, swagger_fun: fun}) do
    apply(controller, fun, [])
  end

  defp merge_paths(path, swagger_map) do
    paths = Map.merge(swagger_map.paths, path, &merge_conflicts/3)
    %{swagger_map | paths: paths}
  end

  defp merge_conflicts(_key, value1, value2) do
    Map.merge(value1, value2)
  end

  defp collect_host(swagger_map, endpoint) do
    endpoint_config = Application.get_env(app_name(), endpoint)

    case Keyword.get(endpoint_config, :url) do
      nil -> swagger_map
      _ -> collect_host_from_endpoint(swagger_map, endpoint_config)
    end
  end

  defp collect_host_from_endpoint(swagger_map, endpoint_config) do
    load_from_system_env = Keyword.get(endpoint_config, :load_from_system_env, false)
    url = Keyword.get(endpoint_config, :url)
    host = Keyword.get(url, :host, "localhost")
    port = Keyword.get(url, :port, 4000)

    swagger_map =
      if (!load_from_system_env) and is_binary(host) and (is_integer(port) or is_binary(port)) do
        Map.put_new(swagger_map, :host, "#{host}:#{port}")
      else
        swagger_map # host / port may be {:system, "ENV_VAR"} tuples or loaded in Endpoint.init callback
      end

    case endpoint_config[:https] do
      nil ->
        swagger_map
      _ ->
        Map.put_new(swagger_map, :schemes, ["https", "http"])
    end
  end

  defp collect_definitions(swagger_map, router) do
    router.__routes__()
    |> Enum.map(&find_controller/1)
    |> Enum.uniq()
    |> Enum.filter(&function_exported?(&1, :swagger_definitions, 0))
    |> Enum.map(&apply(&1, :swagger_definitions, []))
    |> Enum.reduce(swagger_map, &merge_definitions/2)
  end

  defp find_controller(route_map) do
    Module.concat([:Elixir | Module.split(route_map.plug)])
  end

  defp merge_definitions(definitions, swagger_map = %{definitions: existing}) do
    %{swagger_map | definitions: Map.merge(existing, definitions)}
  end
end
