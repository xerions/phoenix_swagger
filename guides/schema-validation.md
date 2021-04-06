# Schema Validation

Besides generator of `swagger` schemas, the `phoenix_swagger` provides validator of input parameters of resources.

Suppose you have following resource in your schema:

```
...
...
"/history": {
    "get": {
        "parameters": [
        {
            "name": "offset",
            "in": "query",
            "type": "integer",
            "format": "int32",
            "description": "Offset the list of returned results by this amount. Default is zero."
        },
        {
            "name": "limit",
            "in": "query",
            "type": "integer",
            "format": "int32",
            "description": "Integer of items to retrieve. Default is 5, maximum is 100."
        }]
     }
}
...
...
```

The `phoenix_swagger` provides `PhoenixSwagger.Validator.parse_swagger_schema/1` API to load a swagger schema by
the given path or list of paths. This API should be called during application startup to parse/load a swagger schema.

After this, use one of the following to validate resources:
* the function `PhoenixSwagger.Validator.validate/2` using request path and parameters
* the default Plug `PhoenixSwagger.Plug.Validate`
* the function `PhoenixSwagger.ConnValidate.validate/1` using `conn`

### `Validator.validate/2`

For example:

```elixir
iex(1)> Validator.validate("/history", %{"limit" => "10"})
{:error,"Type mismatch. Expected Integer but got String.", "#/limit"}

iex(2)> Validator.validate("/history", %{"limit" => 10, "offset" => 100})
:ok
```


### Default Plug

To validate input parameters of your controllers with the default Plug, just add `PhoenixSwagger.Plug.Validate` to your router:

```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug PhoenixSwagger.Plug.Validate
end

scope "/api", MyApp do
  pipe_through :api
  post "/users", UsersController, :send
end
```

On validation errors, the default Plug returns `400` with the following body:
```json
{
  "error": {
    "path": "#/path/to/schema",
    "message": "Expected integer, got null"
  }
}
```

The return code for validation errors is configurable via `:validation_failed_status` parameter.
If `conn.private[:phoenix_swagger][:valid]` is set to `true`, the Plug will skip validation.

### `ConnValidator.validate/1`

Use `ConnValidator.validate/1` to build your own Plugs. It accepts a `conn` and returns `:ok` on validation success. Refer to source for error cases.
