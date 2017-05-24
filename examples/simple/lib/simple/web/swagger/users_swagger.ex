defmodule Simple.Web.UsersSwagger do
  defmacro __using__(_) do
    quote do
      use PhoenixSwagger

      def swagger_definitions do
        %{
          User: swagger_schema do
            title "User"
            description "A user of the app"
            properties do
              id :integer, "User ID"
              name :string, "User name", required: true
              email :string, "Email address", format: :email, required: true
              inserted_at :string, "Creation timestamp", format: :datetime
              updated_at :string, "Update timestamp", format: :datetime
            end
            example %{
              id: 123,
              name: "Joe",
              email: "joe@gmail.com"
            }
          end,
          UserRequest: swagger_schema do
            title "UserRequest"
            description "POST body for creating a user"
            property :user, PhoenixSwagger.Schema.ref(:User), "The user details"
          end,
          UserResponse: swagger_schema do
            title "UserResponse"
            description "Response schema for single user"
            property :data, PhoenixSwagger.Schema.ref(:User), "The user details"
          end,
          UsersResponse: swagger_schema do
            title "UsersReponse"
            description "Response schema for multiple users"
            property :data, PhoenixSwagger.Schema.array(:User), "The users details"
          end
        }
      end

      swagger_path(:index) do
        get "/api/users"
        summary "List Users"
        description "List all users in the database"
        produces "application/json"
        response 200, "OK", PhoenixSwagger.Schema.ref(:UsersResponse), example: %{
          data: [
            %{id: 1, name: "Joe", email: "Joe6@mail.com", inserted_at: "2017-02-08T12:34:55Z", updated_at: "2017-02-12T13:45:23Z"},
            %{id: 2, name: "Jack", email: "Jack7@mail.com", inserted_at: "2017-02-04T11:24:45Z", updated_at: "2017-02-15T23:15:43Z"}
          ]
        }
      end
    end
  end
end
