# Live Reloading

Live reloading can be use to automatically regenerate the swagger files and reload the swagger-ui when controller files change.
To enable live reloading:

 - Ensure `phoenix_swagger` is added as a compiler in your `mix.exs` file
 - Add the path to the swagger json files and controllers to the endpoint `live_reload` config
 - Add the `reloadable_compilers` configuration to the endpoint config, including the `:phoenix_swagger` compiler

```elixir
config :your_app, YourApp.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg|json)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/your_app_web/views/.*(ex)$},
      ~r{lib/your_app_web/controllers/.*(ex)$},
      ~r{lib/your_app_web/templates/.*(eex)$}
    ]
  ],
  reloadable_compilers: [:gettext, :phoenix, :elixir, :phoenix_swagger]
```
