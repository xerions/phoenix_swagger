defmodule Simple.UserControllerTest do
  use Simple.Web.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias Simple.User
  @valid_attrs %{email: "YuSer@gmail.com", name: "Yu Ser"}
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, user_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn, swagger_schema: schema} do
    user = Repo.insert! struct(User, @valid_attrs)
    response =
      conn
      |> get(user_path(conn, :show, user))
      |> validate_resp_schema(schema, "UserResponse")
      |> json_response(200)

    assert response["data"] == %{
      "id" => user.id,
      "name" => user.name,
      "email" => user.email
    }
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, user_path(conn, :show, -1)
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn, swagger_schema: schema} do
    response =
      conn
      |> post(user_path(conn, :create), user: @valid_attrs)
      |> validate_resp_schema(schema, "UserResponse")
      |> json_response(201)

    assert response["data"]["id"]
    assert Repo.get_by(User, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @invalid_attrs
    assert json_response(conn, 422)["error"] == %{
      "message" => "Required property email was not present.",
      "path" => "#/user"
    }
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn, swagger_schema: schema} do
    user = Repo.insert! %User{}
    response =
      conn
      |> put(user_path(conn, :update, user), user: @valid_attrs)
      |> validate_resp_schema(schema, "UserResponse")
      |> json_response(200)

    assert response["data"]["id"]
    assert Repo.get_by(User, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    user = Repo.insert! %User{}
    conn = put conn, user_path(conn, :update, user), user: @invalid_attrs
    assert json_response(conn, 422)["error"] == %{
      "message" => "Required property email was not present.",
      "path" => "#/user"
    }
  end

  test "UserID path param must be an integer", %{conn: conn} do
    conn = put conn, user_path(conn, :update, "abc"), user: @valid_attrs
    assert json_response(conn, 422)["error"] == %{
      "message" => "Type mismatch. Expected Integer but got String.",
      "path" => "#/id"
    }
  end

  test "deletes chosen resource", %{conn: conn} do
    user = Repo.insert! %User{}
    conn = delete conn, user_path(conn, :delete, user)
    assert response(conn, 204)
    refute Repo.get(User, user.id)
  end
end
