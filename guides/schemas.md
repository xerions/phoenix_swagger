# Schemas

Schema definitions are placed in a `swagger_definitions/0` function within each controller module.
This function should return a map in the format of a swagger [definitionsObject](http://swagger.io/specification/#definitionsObject).

The `swagger_schema/2` macro can be used to build a schema definition using the functions provided by the `PhoenixSwagger.Schema` module.

Example:

```elixir
def swagger_definitions do
  %{
    User: swagger_schema do
      title "User"
      description "A user of the application"
      properties do
        name :string, "Users name", required: true
        id :string, "Unique identifier", required: true
        address :string, "Home address"
        preferences (Schema.new do
          properties do
            subscribe_to_mailing_list :boolean, "mailing list subscription", default: true
            send_special_offers :boolean, "special offers list subscription", default: true
          end
        end)
      end
      example %{
        name: "Joe",
        id: "123",
        address: "742 Evergreen Terrace"
      }
    end,
    Users: swagger_schema do
      title "Users"
      description "A collection of Users"
      type :array
      items Schema.ref(:User)
    end
  }
end
```