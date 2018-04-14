defmodule PhoenixSwagger.Plug.SwaggerUI do
  @moduledoc """
  Swagger UI in a plug

  Usage:

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
  plug Plug.Static, at: "/", from: :phoenix_swagger

  plug :match
  plug :dispatch

  @template """
  <!-- HTML for static distribution bundle build -->
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Swagger UI</title>
      <link href="https://fonts.googleapis.com/css?family=Open+Sans:400,700|Source+Code+Pro:300,600|Titillium+Web:400,600,700" rel="stylesheet">
      <link rel="stylesheet" type="text/css" href="./swagger-ui.css" >
      <link rel="icon" type="image/png" href="./favicon-32x32.png" sizes="32x32" />
      <link rel="icon" type="image/png" href="./favicon-16x16.png" sizes="16x16" />
      <style>
        html
        {
          box-sizing: border-box;
          overflow: -moz-scrollbars-vertical;
          overflow-y: scroll;
        }
        *,
        *:before,
        *:after
        {
          box-sizing: inherit;
        }
        body
        {
          margin:0;
          background: #fafafa;
        }
      </style>
    </head>

    <body>
      <div id="swagger-ui"></div>

      <script src="./swagger-ui-bundle.js"> </script>
      <script src="./swagger-ui-standalone-preset.js"> </script>
      <script>
      window.onload = function() {
        // Build a system
        const swagger_url = new URL(window.location);
        swagger_url.pathname = swagger_url.pathname.replace("index.html", "<%= spec_url %>");
        swagger_url.hash = "";
        const ui = SwaggerUIBundle({
          url: swagger_url.href,
          dom_id: '#swagger-ui',
          deepLinking: true,
          presets: [
            SwaggerUIBundle.presets.apis,
            SwaggerUIStandalonePreset
          ],
          plugins: [
            SwaggerUIBundle.plugins.DownloadUrl
          ],
          layout: "StandaloneLayout"
        })
        window.ui = ui
      }
    </script>
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
      [^spec_url] -> Conn.send_file(conn, 200, conn.assigns.swagger_file_path)
      _ -> Conn.send_resp(conn, 404, "not found")
    end
  end

  @doc """
  Plug.init callback

  Options:

   - `otp_app` (required) The name of the app has is hosting the swagger file
   - `swagger_file` (required) The name of the file, eg "swagger.json"

  """
  def init(opts) do
    app = Keyword.fetch!(opts, :otp_app)
    swagger_file = Keyword.fetch!(opts, :swagger_file)
    body = EEx.eval_string(@template, spec_url: swagger_file)
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
end
