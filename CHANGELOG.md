# 0.4.3

  * Include swagger-ui plug `PhoenixSwagger.Plug.SwaggerUI`
  * Allow for a list of types on `PhoenixSwagger.Schema.type`
  * Fix not running all doctests
  * Fix `ArgumentError` in `Phoenix.Swagger.Generate` when routing to plug with keyword opts [#58](https://github.com/xerions/phoenix_swagger/issues/58)

# 0.4.2

  * Fix FunctionClauseError in `response` when no `produces` mime type defined on an operation.

# 0.4.1

  * Fix compilation errors when using `PhoenixSwagger.JsonApi` macros

# 0.4.0

  * Add `PhoenixSwagger.Schema` module that provides a structure which represents
swagger schema.
  * Add `swagger_schema` macro to build a swagger schema.
  * New JSON-API helpers.
  * Provide documentation with ex_doc.
  * And other changes from @everydayhero fork.
