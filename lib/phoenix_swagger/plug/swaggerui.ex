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

  @template_v2 """
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="UTF-8">
    <meta http-equiv="x-ua-compatible" content="IE=edge">
    <title>Swagger UI</title>
    <link rel="icon" type="image/png" href="v2/images/favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="v2/images/favicon-16x16.png" sizes="16x16" />
    <link href='v2/css/typography.css' media='screen' rel='stylesheet' type='text/css'/>
    <link href='v2/css/reset.css' media='screen' rel='stylesheet' type='text/css'/>
    <link href='v2/css/screen.css' media='screen' rel='stylesheet' type='text/css'/>
    <link href='v2/css/reset.css' media='print' rel='stylesheet' type='text/css'/>
    <link href='v2/css/print.css' media='print' rel='stylesheet' type='text/css'/>

    <script src='v2/lib/object-assign-pollyfill.js' type='text/javascript'></script>
    <script src='v2/lib/jquery-1.8.0.min.js' type='text/javascript'></script>
    <script src='v2/lib/jquery.slideto.min.js' type='text/javascript'></script>
    <script src='v2/lib/jquery.wiggle.min.js' type='text/javascript'></script>
    <script src='v2/lib/jquery.ba-bbq.min.js' type='text/javascript'></script>
    <script src='v2/lib/handlebars-4.0.5.js' type='text/javascript'></script>
    <script src='v2/lib/lodash.min.js' type='text/javascript'></script>
    <script src='v2/lib/backbone-min.js' type='text/javascript'></script>
    <script src='v2/swagger-ui.js' type='text/javascript'></script>
    <script src='v2/lib/highlight.9.1.0.pack.js' type='text/javascript'></script>
    <script src='v2/lib/highlight.9.1.0.pack_extended.js' type='text/javascript'></script>
    <script src='v2/lib/jsoneditor.min.js' type='text/javascript'></script>
    <script src='v2/lib/marked.js' type='text/javascript'></script>
    <script src='v2/lib/swagger-oauth.js' type='text/javascript'></script>

    <!-- Some basic translations -->
    <!-- <script src='v2/lang/translator.js' type='text/javascript'></script> -->
    <!-- <script src='v2/lang/ru.js' type='text/javascript'></script> -->
    <!-- <script src='v2/lang/en.js' type='text/javascript'></script> -->

    <script type="text/javascript">
      $(function () {
        var url = window.location.search.match(/url=([^&]+)/);
        if (url && url.length > 1) {
          url = decodeURIComponent(url[1]);
        } else {
          url = window.location.pathname.replace("index.html", "<%= spec_url %>")
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
          <%= validator_url %>
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
          docExpansion: "list",
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
      <a id="logo" href="http://swagger.io"><img class="logo__img" alt="swagger" height="30" width="30" src="v2/images/logo_small.png" /><span class="logo__title">swagger</span></a>
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

  @template_v3 """
  <!-- HTML for static distribution bundle build -->
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>Swagger UI</title>
    <link href="https://fonts.googleapis.com/css?family=Open+Sans:400,700|Source+Code+Pro:300,600|Titillium+Web:400,600,700" rel="stylesheet">
    <link rel="stylesheet" type="text/css" href="./v3/swagger-ui.css" >
    <link rel="icon" type="image/png" href="./v3/favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="./v3/favicon-16x16.png" sizes="16x16" />
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

      body {
        margin:0;
        background: #fafafa;
      }
    </style>
  </head>

  <body>

  <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="position:absolute;width:0;height:0">
    <defs>
      <symbol viewBox="0 0 20 20" id="unlocked">
            <path d="M15.8 8H14V5.6C14 2.703 12.665 1 10 1 7.334 1 6 2.703 6 5.6V6h2v-.801C8 3.754 8.797 3 10 3c1.203 0 2 .754 2 2.199V8H4c-.553 0-1 .646-1 1.199V17c0 .549.428 1.139.951 1.307l1.197.387C5.672 18.861 6.55 19 7.1 19h5.8c.549 0 1.428-.139 1.951-.307l1.196-.387c.524-.167.953-.757.953-1.306V9.199C17 8.646 16.352 8 15.8 8z"></path>
      </symbol>

      <symbol viewBox="0 0 20 20" id="locked">
        <path d="M15.8 8H14V5.6C14 2.703 12.665 1 10 1 7.334 1 6 2.703 6 5.6V8H4c-.553 0-1 .646-1 1.199V17c0 .549.428 1.139.951 1.307l1.197.387C5.672 18.861 6.55 19 7.1 19h5.8c.549 0 1.428-.139 1.951-.307l1.196-.387c.524-.167.953-.757.953-1.306V9.199C17 8.646 16.352 8 15.8 8zM12 8H8V5.199C8 3.754 8.797 3 10 3c1.203 0 2 .754 2 2.199V8z"/>
      </symbol>

      <symbol viewBox="0 0 20 20" id="close">
        <path d="M14.348 14.849c-.469.469-1.229.469-1.697 0L10 11.819l-2.651 3.029c-.469.469-1.229.469-1.697 0-.469-.469-.469-1.229 0-1.697l2.758-3.15-2.759-3.152c-.469-.469-.469-1.228 0-1.697.469-.469 1.228-.469 1.697 0L10 8.183l2.651-3.031c.469-.469 1.228-.469 1.697 0 .469.469.469 1.229 0 1.697l-2.758 3.152 2.758 3.15c.469.469.469 1.229 0 1.698z"/>
      </symbol>

      <symbol viewBox="0 0 20 20" id="large-arrow">
        <path d="M13.25 10L6.109 2.58c-.268-.27-.268-.707 0-.979.268-.27.701-.27.969 0l7.83 7.908c.268.271.268.709 0 .979l-7.83 7.908c-.268.271-.701.27-.969 0-.268-.269-.268-.707 0-.979L13.25 10z"/>
      </symbol>

      <symbol viewBox="0 0 20 20" id="large-arrow-down">
        <path d="M17.418 6.109c.272-.268.709-.268.979 0s.271.701 0 .969l-7.908 7.83c-.27.268-.707.268-.979 0l-7.908-7.83c-.27-.268-.27-.701 0-.969.271-.268.709-.268.979 0L10 13.25l7.418-7.141z"/>
      </symbol>


      <symbol viewBox="0 0 24 24" id="jump-to">
        <path d="M19 7v4H5.83l3.58-3.59L8 6l-6 6 6 6 1.41-1.41L5.83 13H21V7z"/>
      </symbol>

      <symbol viewBox="0 0 24 24" id="expand">
        <path d="M10 18h4v-2h-4v2zM3 6v2h18V6H3zm3 7h12v-2H6v2z"/>
      </symbol>

    </defs>
  </svg>

  <div id="swagger-ui"></div>

  <script src="./v3/swagger-ui-bundle.js"> </script>
  <script src="./v3/swagger-ui-standalone-preset.js"> </script>
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
  get "/:name" do
    spec_url = conn.assigns.spec_url
    case conn.path_params["name"] do
      ^spec_url -> Conn.send_file(conn, 200, conn.assigns.swagger_file_path)
      _ -> Conn.send_resp(conn, 404, "not found")
    end
  end

  @doc """
  Plug.init callback

  Options:

   - `otp_app` (required) The name of the app has is hosting the swagger file
   - `swagger_file` (required) The name of the file, eg "swagger.json"
   - `disable_validator` (optional) When set to true, disables swagger schema validation

  """
  def init(opts) do
    app = Keyword.fetch!(opts, :otp_app)
    swagger_file = Keyword.fetch!(opts, :swagger_file)
    version = opts[:version] || :v2
    disable_validator = Keyword.get(opts, :disable_validator, false)
    validator_url = cond do
      disable_validator == true ->
        "validatorUrl: null,"
      true ->
        ""
    end
    body = EEx.eval_string(template(version), spec_url: swagger_file, validator_url: validator_url)
    swagger_file_path = Path.join(["priv", "static", swagger_file])
    [app: app, body: body, spec_url: swagger_file, swagger_file_path: swagger_file_path]
  end

  defp template(:v2), do: @template_v2
  defp template(:v3), do: @template_v3

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
