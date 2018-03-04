# Operations

`PhoenixSwagger` provides `swagger_path/2` macro that generates swagger specification
for the certain phoenix controller action.

Example:

```elixir
use PhoenixSwagger

swagger_path :index do
  get "/posts"
  description "List blog posts"
  response 200, "Success"
end

def index(conn, _params) do
  posts = Repo.all(Post)
  render(conn, "index.json", posts: posts)
end
```

The `swagger_path` macro takes two parameters:

* Name of controller action;
* `do` block that contains the `swagger` specification for the controller action.

Within the do-end block, the DSL provided by the `PhoenixSwagger.Path` module can be used.
The DSL usually starts with one of the `get`, `put`, `post`, `delete`, `head`, `options` functions,
followed by any functions with first argument being a `PhoenixSwagger.Path.PathObject` struct.

Example:

```elixir
swagger_path :index do
  get "/api/v1/{org_id}/users"
  summary "Query for users"
  description "Query for users. This operation supports with paging and filtering"
  produces "application/json"
  tag "Users"
  operation_id "list_users"
  paging
  parameters do
    org_id :path, :string, "Organization ID", required: true
    zipcode :query, :string, "Address Zip Code", required: true, example: "90210"
    include :query, :array, "Related resources to include in response",
              items: [type: :string, enum: [:organisation, :favourites, :purchases]],
              collectionFormat: :csv
  end
  response 200, "OK", Schema.ref(:Users)
  response 400, "Client Error"
end
```

The `swagger_path` macro layer is just some syntactic sugar over regular elixir functions. Therefore it can easily be extended, for instance, if we want to reuse some common parameters.

For more details on this take a look at [Reusing Swagger Parameters](https://hexdocs.pm/phoenix_swagger/reusing-swagger-parameters.html).
