defmodule Mix.Tasks.Phoenix.Swagger.Generate do
  use Mix.Task

  @shortdoc "Generates swagger.json file based on phoenix router"

  @moduledoc """
  Generates swagger.json file based on phoenix router and controllers.

  Usage:

      mix phoenix.swagger.generate

      mix phoenix.swagger.generate ../swagger.json
  """

  @default_port 4000
  @default_title "<enter your title>"
  @default_version "0.0.1"

  @app_path Enum.at(Mix.Project.load_paths, 0) |> String.split("_build") |> Enum.at(0)
  @swagger_file_name "swagger.js"
  @swagger_file_path @app_path <> @swagger_file_name

  @doc false
  def run([]) do
    run(@swagger_file_path)
  end

  def run([output_file]) do
    run(output_file)
  end

  def run(opts) when is_list(opts) do
    IO.puts """
    Usage: mix phoenix.swagger.generate [FILE]

    With no FILE, default swagger file - #{@swagger_file_path}.
    """
  end

  def run(output_file) do
    # initial swagger API data
    swagger_map = %{swagger: "2.0"}
    # get some information about our application
    app = Mix.Project.get.application
    project = Mix.Project.get.project
    # get application and router modules
    app_name = project |> Keyword.get(:app)
    app_mod = app |> Keyword.get(:mod) |> elem(0)
    router_mod = Module.concat([app_mod, :Router])
    # append path with the given application
    ebin = @app_path <> "_build/" <> (Mix.env |> to_string) <> "/lib/" <> (app_name |> to_string) <> "/ebin"
    Code.append_path(ebin)
    # collect data and generate swagger map
    result = collect_info(swagger_map)
             |> collect_host(app_name, app_mod)
             |> collect_paths(router_mod, app_mod)
             |> Poison.encode!
    File.write(output_file, result)
    Code.delete_path(ebin)
    IO.puts "Done."
  end

  @doc false
  defp collect_paths(swagger_map, router_mod, app_mod) do
    # get routes that have pipeline - api
    api_routes = get_api_routes(router_mod)
    # build 'paths' swagger attribute
    paths = List.foldl(api_routes, %{},
      fn (route_map, acc) ->
        {controller, swagger_fun} = get_api(app_mod, route_map)
        # phoenix router accepts parameters in a '/path/path/:id'
        # format, but the swagger has another format, that's why
        # why we need to convert it to swagger format '/path/{id}'
        path = format_path(route_map.path)
        # check that give controller haev swagger_.* function and call it
        case function_exported?(controller, swagger_fun, 0) do
          true ->
            {[description], parameters, response_code,
             response_description, meta} = apply(controller, swagger_fun, [])
            # convert list of parameters to maps
            parameters = get_parameters(parameters)
            # make 'description' and 'parameters' maps
            request_map = Map.put_new(%{}, :description, description)
            request_map = Map.put_new(request_map, :parameters,  parameters)
            # make internals of 'responses' map
            response_map = Map.put_new(%{}, :description, response_description)
            response_map = case meta do
                             [] ->
                               response_map
                             [meta] ->
                               Map.put_new(response_map, :schema, meta)
                           end
            # make response map - #{http_code: .....}
            response = Map.put_new(%{}, response_code |> to_string, response_map)
            # make rest_method map (get:, update: ....)
            rest_method  = Map.put_new(%{}, route_map.verb, request_map)
            # finish path map
            body  = Map.put_new(rest_method[route_map.verb], :responses, response)
            # add http method to the tree
            path_map  = Map.put_new(%{}, route_map.verb, body)
            # finish paths
            Map.put_new(acc, path, path_map)
          _ ->
            # A controller has no swagger_[action] function, so
            # we ust miss this API
            acc
        end
      end)

    Map.put_new(swagger_map, :paths, paths)
  end

  @doc false
  defp collect_host(swagger_map, app_name, app_mod) do
    endpoint_config = Application.get_env(app_name,Module.concat([app_mod, :Endpoint]))
    [{:host, host}] = Keyword.get(endpoint_config, :url, [{:host, "localhost"}])
    [{:port, port}] = Keyword.get(endpoint_config, :http, [{:port, @default_port}])
    https = Keyword.get(endpoint_config, :https, nil)
    swagger_map = Map.put_new(swagger_map, :host, host <> ":" <> to_string(port))
    case https do
      nil ->
        swagger_map
      _ ->
        Map.put_new(swagger_map, :schemes, ["https", "http"])
    end
  end

  @doc false
  defp collect_info(swagger_map) do
    case function_exported?(Mix.Project.get, :swagger_info, 0) do
      true ->
        info = Mix.Project.get.swagger_info
        title = Keyword.get(info, :title, nil)
        version = Keyword.get(info, :version, nil)
        # collect :info swagger fields to the map
        info = List.foldl(info, %{},
          fn ({info_key, info_val}, map) ->
            Map.put_new(map, info_key, info_val)
          end)
        # :title and :version are mandatory fields,
        # so we need to check and add default values
        # if they are not exists
        info = if title == nil do
          Map.put_new(info, :title, @default_title)
        end
        info = if version == nil do
          Map.put_new(info, :version, @default_version)
        end
        # resulted :info swagger field
        Map.put_new(swagger_map, :info, info)
      false ->
        # we have swagger_info/0 in the mix.exs, so we
        # just adding default values for the mandatory
        # fields
        info = Map.put_new(%{}, :title, @default_title)
        info = Map.put_new(info, :version, @default_version)
        Map.put_new(swagger_map, :info, info)
    end
  end

  @doc false
  defp format_path(path) do
    case String.split(path, ":") do
      [_] -> path
      path_list ->
        List.foldl(path_list, "", fn(p, acc) ->
          if not String.starts_with?(p, "/") do
            [parameter | rest] = String.split(p, "/")
            parameter = acc <> "{" <> parameter <> "}"
            case rest do
              [] -> parameter
              _ ->  parameter <> "/" <> Enum.join(rest, "/")
            end
          else
            acc <> p
          end
        end)
    end
  end

  @doc false
  defp get_api_routes(router_mod) do
    Enum.filter(router_mod.__routes__,
      fn(route_path) ->
        route_path.pipe_through == [:api]
      end)
  end

  @doc false
  defp get_parameters(parameters) do
    Enum.map(parameters,
      fn({:param, params_list}) ->
        Enum.into(params_list, %{})
      end) |> :lists.flatten
  end

  @doc false
  defp get_api(app_mod, route_map) do
    controller = Module.concat([:Elixir | Module.split(route_map.plug)])
    swagger_fun = ("swagger_" <> to_string(route_map.opts)) |> String.to_atom
    if Code.ensure_loaded?(controller) == false do
      raise "Error: #{controller} module didn't load."
    else
      {controller, swagger_fun}
    end
  end

end
