# Changelog

## v0.8.4 - 2025-05-29

  * swagger-ui-dist updated to 5.2.0.
  * Fix validation of boolean properties. Thanks to @charl3sj
  * Allow nullable `$ref`. Thanks to @ericsullivan
  * Nullable fields validated correctly. Thanks to @ericsullivan
  * Add support SwaggerUI config object injection. Thanks to @heroinbob
  * Add support to have property names with `-` symbol. Thanks to @fahadnaeemkhan
  * Documentation improvements. Thanks to @kianmeng and @leticiapenha
  * Use Elixir formatter. Thanks to @naps62
  * Remove ex_json_schema from startup. Thanks to @lukaszsamson
  * Update dependencies and phoenix_swagger itself for Elixir >= 1.16.0

## v0.8.3 - 2021-01-15

  * Fix broken param parsing caused from Plug 1.11.0
  * Allow swagger ui validator url to be customized
  * `validatorUrl` replaced with `configUrl`
  * Warning messages fixed for Elixir 1.11
  * dialyxir, plug, ex_json_schema and other dependencies are updated to the latests versions

## v0.8.2 - 2019-12-12

  * Add support for Phoenix ~> 1.4.9
  * Ability to configure json library e.g. config `:phoenix_swagger, json_library: Jason`
  * Improvements in SwagerUI Plug
  * Update dependencies
  * Bug fixes

## v0.8.1 - 2018-07-06

  * Fix for crash on non-GET requests
  * Fix compilation error running `mix phx.swagger.generate` before `mix compile`
  * Validate number type in query parameter
  * Add `id` and `type` properties to the `included`-items schema
  * Add `Schema.nullable` function to set the `x-nullable` property
  * Add `nullable:` option to `JsonSchema.relationship` function
  * Handle `x-nullable` schemas in `SchemaTest`
  * Add `deprecated` flag for operations

## v0.8.0 - 2018-03-13

  * Passing module names and output path as mix task parameters is no longer supported.
  * Inferring default module names from mix project is no longer supported.
  * Swagger file outputs, router module and optional endpoint module must now be specified in application config:

    ```elixir
    config :my_app, :phoenix_swagger,
      swagger_files: %{
        "priv/static/swagger.json" => [router: MyAppWeb.Router, endpoint: MyAppWeb.Endpoint],
        # additional swagger files here
      }
    ```

  * `phoenix_swagger` can now be run as a mix compiler task, ensuring that the generated swagger is kept in sync with code, and enabling live reloading.

    ```elixir
    compilers: [:phoenix, :gettext, :phoenix_swagger] ++ Mix.compilers
    ```

  * The HTTP verb and path can now be inferred from the phoenix router:

    ```elixir
    swagger_path :show do
      get "/api/users/{id}
      description "Gets a user by ID"
      response 200, "OK", Schema.ref(User)
    end
    ```
    Can now be written without the `get`:

    ```elixir
    swagger_path :show do
      description "Gets a user by ID"
      response 200, "OK", Schema.ref(User)
    end
    ```

    Note that if your controller contains a `delete/2` function (such as when using the `resources` convention), then calling `delete/2` from `PhoenixSwagger.Path` will now cause a compilation error. To avoid this problem, include the full module (shown below), or simply remove the line and allow the verb and path to be inferred from the route:

    ```elixir
    swagger_path(:delete) do
      PhoenixSwagger.Path.delete "/api/users/{id}"
      summary "Delete User"
    end
    ```

## v0.7.1 - 2017-11-09

  * Use the :load_from_system_env Endpoint config flag to detect dynamic host and port configuration

## v0.7.0 - 2017-11-09

  * Minor fix that supports the Phoenix 1.3 namespacing, where it is {Project}Web instead of {Project}.Web.
  * Add support for has_many relationships for JSON-API resource schemas
  * Upgrade to swagger-ui 3.1.7
  * Tests for nested and non-nested required parameters for `PhoenixSwagger.Plug.Validate`.
  *  Decode parameter names using `Plug.Conn.Query.decode` and walk `conn.params` to find the nested param as `conn.params` is already nested while `parameter["name"]` is not when received by `PhoenixSwagger.Plug.Validate.validate_query_params/2`.

## v0.6.4 - 2017-07-15

  * Adds support to enable security by endpoint
  * `PhoenixSwagger.Plug.Validate` sets response content type on error to `application/json`
  * `PhoenixSwagger.Plug.Validate` accepts `:validation_failed_status` option, defaults to 400
  * Example application includes usage of validator

## v0.6.3 - 2017-06-17

  * Adds support for custom Endpoint module names by passing `--endpoint`
  * Added patch request support

## v0.6.2 - 2017-05-09

  * fix path assignation of a swagger specification file in UI plug
  * add `disable_validator` option to disable/enable validation of a
swagger schema.

## v0.6.1 - 2017-05-09

  * Provide default host and port when generating swagger host config
  * Suppress host config when dynamic hostname or port are used

## v0.6.0 - 2017-05-03

  * Use phoenix 1.3 conventions for mix tasks and module names
  * Add `PhoenixSwagger.SchemaTest` module for response validation
  * Swagger UI plug redirects / to /index.html automatically avoiding errors when fetching assets.
  * Swagger UI configured to list all operations by default

## v0.5.1 - 2017-03-29

  * Allow property schemas to be declared inline using `Schema.new` macro
  * Allow schemas to include an example
  * Add support for `discriminator` in polymorphic schemas
  * Do not set a host if a url has not been provided
  * Ability to validate boolean values

## v0.5.0 - 2017-03-13

  * Include swagger-ui plug `PhoenixSwagger.Plug.SwaggerUI`
  * Allow for a list of types on `PhoenixSwagger.Schema.type`
  * Fix not running all doctests
  * Fix `ArgumentError` in `Phoenix.Swagger.Generate` when routing to plug with keyword opts [#58](https://github.com/xerions/phoenix_swagger/issues/58)

## v0.4.2 - 2017-02-22

  * Fix FunctionClauseError in `response` when no `produces` mime type defined on an operation.

## v0.4.1 - 2017-02-21

  * Fix compilation errors when using `PhoenixSwagger.JsonApi` macros

## v0.4.0 - 2017-02-20

  * Add `PhoenixSwagger.Schema` module that provides a structure which represents
swagger schema.
  * Add `swagger_schema` macro to build a swagger schema.
  * New JSON-API helpers.
  * Provide documentation with ex_doc.
  * And other changes from @everydayhero fork.
