# JSON:API Helpers

The `PhoenixSwagger.JsonApi` module provides helpers for constructing JSON:API schemas easily.
`PhoenixSwagger.JsonApi.resource/1` describes a JSON:API [resource object](http://jsonapi.org/format/#document-resource-objects).
`PhoenixSwagger.JsonApi.page/1` and `PhoenixSwagger.JsonApi.single/1` can then be used to wrap a resource in a JSON:API [top level object](http://jsonapi.org/format/#document-top-level)

Example:

```elixir
use PhoenixSwagger

def swagger_definitions do
  %{
    UserResource: JsonApi.resource do
      description "A user that may have one or more supporter pages."
      attributes do
        phone :string, "Users phone number"
        full_name :string, "Full name"
        user_updated_at :string, "Last update timestamp UTC", format: "ISO-8601"
        user_created_at :string, "First created timestamp UTC"
        email :string, "Email", required: true
        birthday :string, "Birthday in YYYY-MM-DD format"
        address Schema.ref(:Address), "Users address"
      end
      link :self, "The link to this user resource"
      relationship :preferences
      relationship :posts, type: :has_many
    end,
    Users: JsonApi.page(:UserResource),
    User: JsonApi.single(:UserResource)
  }
end

swagger_path :index do
  get "/api/v1/users"
  paging size: "page[size]", number: "page[number]"
  response 200, "OK", Schema.ref(:Users)
end
```

