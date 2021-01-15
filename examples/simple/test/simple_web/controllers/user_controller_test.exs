defmodule SimpleWeb.UserControllerTest do
  use SimpleWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias Simple.Repo
  alias Simple.Accounts
  alias Simple.Accounts.User

  @create_attrs %{email: "joe@gmail.com", name: "some name"}
  @update_attrs %{email: "jill@yahoo.com", name: "some updated name"}
  @invalid_attrs %{}

  def fixture(:user) do
    {:ok, user} = Accounts.create_user(@create_attrs)
    user
  end

  defp create_user(_) do
    user = fixture(:user)
    {:ok, user: user}
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all users", %{conn: conn, swagger_schema: schema} do
      conn =
        conn
        |> get(Routes.user_path(conn, :index))
        |> validate_resp_schema(schema, "UsersResponse")

      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "show" do
    test "shows user by ID", %{conn: conn, swagger_schema: schema} do
      user = Repo.insert!(struct(User, @create_attrs))

      response =
        conn
        |> get(Routes.user_path(conn, :show, user))
        |> validate_resp_schema(schema, "UserResponse")
        |> json_response(200)

      assert response["data"] == %{
               "id" => user.id,
               "name" => user.name,
               "email" => user.email
             }
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, Routes.user_path(conn, :show, -1))
      end)
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn, swagger_schema: schema} do
      conn = post(conn, Routes.user_path(conn, :create), user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn =
        conn
        |> get(Routes.user_path(conn, :show, id))
        |> validate_resp_schema(schema, "UserResponse")

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "email" => "joe@gmail.com",
               "name" => "some name"
             }
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)

      assert json_response(conn, 422)["error"] == %{
               "message" => "Required properties email, name were not present.",
               "path" => "#/user"
             }
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{
      conn: conn,
      user: %User{id: id} = user,
      swagger_schema: schema
    } do
      conn = put(conn, Routes.user_path(conn, :update, user), user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn =
        conn
        |> get(Routes.user_path(conn, :show, id))
        |> validate_resp_schema(schema, "UserResponse")

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "email" => "jill@yahoo.com",
               "name" => "some updated name"
             }
    end

    test "does not update user and renders errors when data is invalid", %{conn: conn} do
      user = Repo.insert!(%User{})
      conn = put(conn, Routes.user_path(conn, :update, user), user: @invalid_attrs)

      assert json_response(conn, 422)["error"] == %{
               "message" => "Required properties email, name were not present.",
               "path" => "#/user"
             }
    end

    test "UserID path param must be an integer", %{conn: conn} do
      conn = put(conn, Routes.user_path(conn, :update, "abc"), user: @update_attrs)

      assert json_response(conn, 422)["error"] == %{
               "message" => "Type mismatch. Expected Integer but got String.",
               "path" => "#/id"
             }
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, Routes.user_path(conn, :delete, user))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.user_path(conn, :show, user))
      end)
    end
  end
end
