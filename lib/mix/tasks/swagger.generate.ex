defmodule Mix.Tasks.Phoenix.Swagger.Generate do
  use Mix.Task

  @recursive true

  @shortdoc "Generates swagger.json file based on phoenix router"

  @moduledoc """
  Generates swagger.json file based on phoenix router and controllers.

  Usage:

      mix phoenix.swagger.generate

      mix phoenix.swagger.generate ../swagger.json

      mix phoenix.swagger.generate ../swagger.json --router MyApp.Router
  """

  @app_path Enum.at(Mix.Project.load_paths, 0) |> String.split("_build") |> Enum.at(0)
  @app_module Mix.Project.get.application[:mod] |> elem(0)
  @app_name Mix.Project.get.project[:app]

  @default_port 4000
  @default_title "<enter your title>"
  @default_version "0.0.1"
  @default_swagger_file_path @app_path <> "swagger.json"
  @default_router_module Module.concat([@app_module, :Router])

  def run(args) do
    Mix.Task.reenable("phoenix.swagger.generate")
    Code.append_path("#{@app_path}_build/#{Mix.env}/lib/#{@app_name}/ebin")
    {switches, params, _unknown} = OptionParser.parse(
      args,
      switches: [router: :string, help: :boolean],
      aliases: [r: :router, h: :help])

    if (Keyword.get(switches, :help)) do
      usage
    else
      router = load_router(switches)
      output_file = Enum.at(params, 0, @default_swagger_file_path)
      write_file(output_file, swagger_document(router))
      IO.puts "Generated #{output_file}"
    end
  end

  defp usage do
    IO.puts """
    Usage: mix phoenix.swagger.generate FILE --router ROUTER

    With no FILE, default swagger file #{@default_swagger_file_path}
    With no ROUTER, defaults to @default_router_module
    """
  end

  defp write_file(output_file, contents) do
    directory = Path.dirname(output_file)
    unless File.exists? directory do
      File.mkdir_p! directory
    end
    File.write!(output_file, contents)
  end

  defp load_router(switches) do
    {:module, router} =
      switches
      |> Keyword.get(:router, @default_router_module)
      |> List.wrap()
      |> Module.concat()
      |> Code.ensure_loaded()

    router
  end

  defp swagger_document(router) do
    router
    |> collect_info()
    |> collect_host()
    |> collect_paths(router)
    |> collect_definitions(router)
    |> Poison.encode!(pretty: true)
  end

  defp collect_info(router) do
    cond do
      function_exported?(router, :swagger_info, 0) ->
        Map.merge(default_swagger_info, router.swagger_info())

      function_exported?(Mix.Project.get, :swagger_info, 0) ->
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
    router.__routes__
    |> Enum.map(&find_swagger_path_function/1)
    |> Enum.filter(&controller_function_exported?/1)
    |> Enum.map(&get_swagger_path/1)
    |> Enum.reduce(swagger_map, &merge_paths/2)
  end

  defp find_swagger_path_function(route_map) do
    controller = find_controller(route_map)
    swagger_fun = "swagger_path_#{to_string(route_map.opts)}" |> String.to_atom

    unless Code.ensure_loaded?(controller) do
      raise "Error: #{controller} module didn't load."
    end

    %{
      controller: controller,
      swagger_fun: swagger_fun,
      path: format_path(route_map.path)
    }
  end

  defp format_path(path) do
    Regex.replace(~r/:([^\/]+)/, path, "{\\1}")
  end

  defp controller_function_exported?(%{controller: controller, swagger_fun: fun}) do
    function_exported?(controller, fun, 0)
  end

  defp get_swagger_path(%{controller: controller, swagger_fun: fun, path: path}) do
    %{^path => _action} = apply(controller, fun, [])
  end

  defp merge_paths(path, swagger_map) do
    paths = Map.merge(swagger_map.paths, path, &merge_conflicts/3)
    %{swagger_map | paths: paths}
  end

  defp merge_conflicts(_key, value1, value2) do
    Map.merge(value1, value2)
  end

  defp collect_host(swagger_map) do
    endpoint_config = Application.get_env(@app_name, Module.concat([@app_module, :Endpoint]))

    url = Keyword.get(endpoint_config, :url, [host: "localhost", port: @default_port])
    host = Keyword.get(url, :host, "localhost")
    port = Keyword.get(url, :port, @default_port)
    swagger_map = Map.put_new(swagger_map, :host, "#{host}:#{port}")

    case endpoint_config[:https] do
      nil ->
        swagger_map
      _ ->
        Map.put_new(swagger_map, :schemes, ["https", "http"])
    end
  end

  defp collect_definitions(swagger_map, router) do
    router.__routes__
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
