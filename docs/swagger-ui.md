# Swagger UI

PhoenixSwagger includes a plug with all static assets required to host swagger-ui from your Phoenix application.

Usage:

Generate a swagger file in your applications `priv/static` dir:

```elixir
config :my_app, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: MyAppWeb.Router]
  }
```

```
mix phx.swagger.generate
```

Add a swagger scope to your router, and forward all requests to SwaggerUI

```elixir
    scope "/api/swagger" do
      forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :myapp, swagger_file: "swagger.json"
    end
```

Run the server with `mix phx.server` and browse to `localhost:4000/api/swagger`,
Swagger-ui should be shown with your swagger spec loaded.

See the [examples/simple](https://github.com/xerions/phoenix_swagger/tree/master/examples/simple) project for a runnable example with swagger-ui.

