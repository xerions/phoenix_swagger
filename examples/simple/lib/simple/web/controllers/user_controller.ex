defmodule Simple.Web.UserController do
  use Simple.Web, :controller
  use PhoenixSwagger

  alias Simple.User

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
        property :user, Schema.ref(:User), "The user details"
      end,
      UserResponse: swagger_schema do
        title "UserResponse"
        description "Response schema for single user"
        property :data, Schema.ref(:User), "The user details"
      end,
      UsersResponse: swagger_schema do
        title "UsersReponse"
        description "Response schema for multiple users"
        property :data, Schema.array(:User), "The users details"
      end
    }
  end


  swagger_path(:index) do
    get "/api/users"
    summary "List Users"
    description "List all users in the database"
    produces "application/json"
    response 200, "OK", Schema.ref(:UsersResponse), example: %{
      data: [
        %{id: 1, name: "Joe", email: "Joe6@mail.com", inserted_at: "2017-02-08T12:34:55Z", updated_at: "2017-02-12T13:45:23Z"},
        %{id: 2, name: "Jack", email: "Jack7@mail.com", inserted_at: "2017-02-04T11:24:45Z", updated_at: "2017-02-15T23:15:43Z"}
      ]
    }
  end
  def index(conn, _params) do
    users = Repo.all User
    render(conn, "index.json", users: users)
  end

  swagger_path(:create) do
    post "/api/users"
    summary "Create user"
    description "Creates a new user"
    consumes "application/json"
    produces "application/json"
    parameter :user, :body, Schema.ref(:UserRequest), "The user details", example: %{
      user: %{name: "Joe", email: "Joe1@mail.com"}
    }
    response 201, "User created OK", Schema.ref(:UserResponse), example: %{
      data: %{
        id: 1, name: "Joe", email: "Joe2@mail.com", inserted_at: "2017-02-08T12:34:55Z", updated_at: "2017-02-12T13:45:23Z"
      }
    }
  end
  def create(conn, %{"user" => user_params}) do
    changeset = User.changeset(%User{}, user_params)

    case Repo.insert(changeset) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", user_path(conn, :show, user))
        |> render("show.json", user: user)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Simple.Web.ChangesetView, "error.json", changeset: changeset)
    end
  end

  swagger_path(:show) do
    get "/api/users/{id}"
    summary "Show User"
    description "Show a user by ID"
    produces "application/json"
    parameter :id, :path, :integer, "User ID", required: true, example: 123
    response 200, "OK", Schema.ref(:UserResponse), example: %{
      data: %{
        id: 123, name: "Joe", email: "Joe3@mail.com", inserted_at: "2017-02-08T12:34:55Z", updated_at: "2017-02-12T13:45:23Z"
      }
    }
  end
  def show(conn, %{"id" => id}) do
    user = Repo.get!(User, id)
    render(conn, "show.json", user: user)
  end

  swagger_path(:update) do
    put "/api/users/{id}"
    summary "Update user"
    description "Update all attributes of a user"
    consumes "application/json"
    produces "application/json"
    parameters do
      id :path, :integer, "User ID", required: true, example: 3
      user :body, Schema.ref(:UserRequest), "The user details", example: %{
        user: %{name: "Joe", email: "joe4@mail.com"}
      }
    end
    response 200, "Updated Successfully", Schema.ref(:UserResponse), example: %{
      data: %{
        id: 3, name: "Joe", email: "Joe5@mail.com", inserted_at: "2017-02-08T12:34:55Z", updated_at: "2017-02-12T13:45:23Z"
      }
    }
  end
  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Repo.get!(User, id)
    changeset = User.changeset(user, user_params)

    case Repo.update(changeset) do
      {:ok, user} ->
        render(conn, "show.json", user: user)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Simple.Web.ChangesetView, "error.json", changeset: changeset)
    end
  end

  swagger_path(:delete) do
    delete "/api/users/{id}"
    summary "Delete User"
    description "Delete a user by ID"
    parameter :id, :path, :integer, "User ID", required: true, example: 3
    response 203, "No Content - Deleted Successfully"
  end
  def delete(conn, %{"id" => id}) do
    user = Repo.get!(User, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(user)

    send_resp(conn, :no_content, "")
  end
end
