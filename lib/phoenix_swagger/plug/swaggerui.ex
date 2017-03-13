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

  # Serve static assets before routing
  plug Plug.Static, at: "/", from: :phoenix_swagger

  plug :match
  plug :dispatch

  @template """
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="UTF-8">
    <meta http-equiv="x-ua-compatible" content="IE=edge">
    <title>Swagger UI</title>
    <link rel="icon" type="image/png" href="images/favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="images/favicon-16x16.png" sizes="16x16" />
    <link href='css/typography.css' media='screen' rel='stylesheet' type='text/css'/>
    <link href='css/reset.css' media='screen' rel='stylesheet' type='text/css'/>
    <link href='css/screen.css' media='screen' rel='stylesheet' type='text/css'/>
    <link href='css/reset.css' media='print' rel='stylesheet' type='text/css'/>
    <link href='css/print.css' media='print' rel='stylesheet' type='text/css'/>

    <script src='lib/object-assign-pollyfill.js' type='text/javascript'></script>
    <script src='lib/jquery-1.8.0.min.js' type='text/javascript'></script>
    <script src='lib/jquery.slideto.min.js' type='text/javascript'></script>
    <script src='lib/jquery.wiggle.min.js' type='text/javascript'></script>
    <script src='lib/jquery.ba-bbq.min.js' type='text/javascript'></script>
    <script src='lib/handlebars-4.0.5.js' type='text/javascript'></script>
    <script src='lib/lodash.min.js' type='text/javascript'></script>
    <script src='lib/backbone-min.js' type='text/javascript'></script>
    <script src='swagger-ui.js' type='text/javascript'></script>
    <script src='lib/highlight.9.1.0.pack.js' type='text/javascript'></script>
    <script src='lib/highlight.9.1.0.pack_extended.js' type='text/javascript'></script>
    <script src='lib/jsoneditor.min.js' type='text/javascript'></script>
    <script src='lib/marked.js' type='text/javascript'></script>
    <script src='lib/swagger-oauth.js' type='text/javascript'></script>

    <!-- Some basic translations -->
    <!-- <script src='lang/translator.js' type='text/javascript'></script> -->
    <!-- <script src='lang/ru.js' type='text/javascript'></script> -->
    <!-- <script src='lang/en.js' type='text/javascript'></script> -->

    <script type="text/javascript">
      $(function () {
        var url = window.location.search.match(/url=([^&]+)/);
        if (url && url.length > 1) {
          url = decodeURIComponent(url[1]);
        } else {
          url = "<%= spec_url %>";
        }

        hljs.configure({
          highlightSizeThreshold: 5000
        });

        // Pre load translate...
        if(window.SwaggerTranslator) {
          window.SwaggerTranslator.translate();
        }
        window.swaggerUi = new SwaggerUi({
          url: url,
          dom_id: "swagger-ui-container",
          supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
          onComplete: function(swaggerApi, swaggerUi){
            if(typeof initOAuth == "function") {
              initOAuth({
                clientId: "your-client-id",
                clientSecret: "your-client-secret-if-required",
                realm: "your-realms",
                appName: "your-app-name",
                scopeSeparator: " ",
                additionalQueryStringParams: {}
              });
            }

            if(window.SwaggerTranslator) {
              window.SwaggerTranslator.translate();
            }
          },
          onFailure: function(data) {
            log("Unable to Load SwaggerUI");
          },
          docExpansion: "none",
          jsonEditor: false,
          defaultModelRendering: 'schema',
          showRequestHeaders: false,
          showOperationIds: false
        });

        window.swaggerUi.load();

        function log() {
          if ('console' in window) {
            console.log.apply(console, arguments);
          }
        }
    });
    </script>
  </head>

  <body class="swagger-section">
  <div id='header'>
    <div class="swagger-ui-wrap">
      <a id="logo" href="http://swagger.io"><img class="logo__img" alt="swagger" height="30" width="30" src="images/logo_small.png" /><span class="logo__title">swagger</span></a>
      <form id='api_selector'>
        <div class='input'><input placeholder="http://example.com/api" id="input_baseUrl" name="baseUrl" type="text"/></div>
        <div id='auth_container'></div>
        <div class='input'><a id="explore" class="header__btn" href="#" data-sw-translate>Explore</a></div>
      </form>
    </div>
  </div>

  <div id="message-bar" class="swagger-ui-wrap" data-sw-translate>&nbsp;</div>
  <div id="swagger-ui-container" class="swagger-ui-wrap"></div>
  </body>
  </html>
  """

  # Render the index template for "/" or "/index.html"
  get "/", do: render_index(conn)
  get "/index.html", do: render_index(conn)

  # Render the swagger.json file or 404 for any other file
  get "/:name" do
    spec_url = conn.assigns.spec_url
    case conn.path_params["name"] do
      ^spec_url -> Plug.Conn.send_file(conn, 200, conn.assigns.swagger_file_path)
      _ -> Plug.Conn.send_resp(conn, 404, "not found")
    end
  end

  def render_index(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, conn.assigns.index_body)
  end

  @doc """
  Plug.init callback
  """
  def init(otp_app: app, swagger_file: swagger_file) do
    body = EEx.eval_string(@template, spec_url: swagger_file)
    swagger_file_path = Path.join([Application.app_dir(app), "priv/static", swagger_file])
    [body: body, spec_url: swagger_file, swagger_file_path: swagger_file_path]
  end

  @doc """
  Plug.call callback
  """
  def call(conn, body: body, spec_url: url, swagger_file_path: swagger_file_path) do
    conn
    |> Plug.Conn.assign(:index_body, body)
    |> Plug.Conn.assign(:spec_url, url)
    |> Plug.Conn.assign(:swagger_file_path, swagger_file_path)
    |> super([])
  end
end
