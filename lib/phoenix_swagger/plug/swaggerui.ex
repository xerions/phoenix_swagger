defmodule PhoenixSwagger.Plug.SwaggerUI do
  @moduledoc """
  Swagger UI in a plug.

  ## Examples

  Generate a swagger file and place it in your applications `priv/static` dir:

      mix phoenix.swagger.generate priv/static/myapp.json

  Add a swagger scope to your router, and forward all requests to SwaggerUI

      scope "myapp/api/swagger" do
        forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :myapp, swagger_file: "myapp.json"
      end

  Run the server with `mix phoenix.server` and browse to `localhost:8080/myapp/api/swagger/`,
  swagger-ui should be shown with your swagger spec loaded.
  """

  use Plug.Router
  alias Plug.Conn

  # Serve static assets before routing
  plug(Plug.Static, at: "/", from: :phoenix_swagger)

  plug(:match)
  plug(:dispatch)

  @template """
  <!-- HTML for static distribution bundle build -->
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Swagger UI</title>
      <link rel="stylesheet" type="text/css" href="./swagger-ui.css" />
      <link rel="stylesheet" type="text/css" href="index.css" />
      <link rel="icon" type="image/png" href="./favicon-32x32.png" sizes="32x32" />
      <link rel="icon" type="image/png" href="./favicon-16x16.png" sizes="16x16" />
    </head>

    <body>
      <div id="swagger-ui"></div>
      <script src="./swagger-ui-bundle.js" charset="UTF-8"> </script>
      <script src="./swagger-ui-standalone-preset.js" charset="UTF-8"> </script>
      <script src="./swagger-initializer.js" charset="UTF-8"> </script>
    </body>
  </html>
  """

  # Redirect / to /index.html
  get "/" do
    base_path = conn.request_path |> String.trim_trailing("/")

    conn
    |> Conn.put_resp_header("location", "#{base_path}/index.html")
    |> Conn.put_resp_content_type("text/html")
    |> Conn.send_resp(302, "Redirecting")
  end

  get "/index.html" do
    conn
    |> Conn.put_resp_content_type("text/html")
    |> Conn.send_resp(200, conn.assigns.index_body)
  end

  # Render the swagger.json file or 404 for any other file
  get "/*paths" do
    spec_url = conn.assigns.spec_url

    case conn.path_params["paths"] do
      [^spec_url] ->
        Conn.send_file(conn, 200, conn.assigns.swagger_file_path)

      _ ->
        if accept_json?(conn) do
          conn
          |> Conn.put_resp_content_type("application/json")
          |> Conn.send_resp(404, PhoenixSwagger.json_library().encode!(%{Error: "not found"}))
          |> halt
        else
          Conn.send_resp(conn, 404, "not found")
        end
    end
  end

  match "/*paths" do
    Conn.send_resp(conn, 405, "method not allowed")
  end

  @doc """
  Plug.init callback

  Options:

   - `otp_app` (required) The name of the app has is hosting the swagger file
   - `swagger_file` (required) The name of the file, eg "swagger.json"
   - `config_object` (optional) These values are injected into the config object passed to SwaggerUI.
   - `config_url` (optional) Populates the `configUrl` Swagger UI parameter. A URL to fetch an external configuration document from.

  """
  def init(opts) do
    app = Keyword.fetch!(opts, :otp_app)
    swagger_file = Keyword.fetch!(opts, :swagger_file)
    config_object = Keyword.get(opts, :config_object, %{})
    config_url = format_config_url(opts)

    body =
      EEx.eval_string(@template,
        config_object: config_object,
        config_url: config_url,
        spec_url: swagger_file
      )

    swagger_file_path = Path.join(["priv", "static", swagger_file])

    [app: app, body: body, spec_url: swagger_file, swagger_file_path: swagger_file_path]
  end

  @doc """
  Plug.call callback
  """
  def call(conn, app: app, body: body, spec_url: url, swagger_file_path: swagger_file_path) do
    conn
    |> Conn.assign(:index_body, body)
    |> Conn.assign(:spec_url, url)
    |> Conn.assign(:swagger_file_path, Path.join([Application.app_dir(app), swagger_file_path]))
    |> super([])
  end

  defp accept_json?(conn) do
    case get_req_header(conn, "accept") do
      ["application/json"] -> true
      _ -> false
    end
  end

  defp format_config_url(opts) do
    case Keyword.fetch(opts, :config_url) do
      :error -> :undefined
      {:ok, nil} -> :undefined
      {:ok, url} -> "\"#{url}\""
    end
  end
end
