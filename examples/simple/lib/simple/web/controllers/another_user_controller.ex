defmodule Simple.Web.AnotherUserController do
  use Simple.Web, :controller

  alias Simple.User

  use Simple.Web.UsersSwagger

  def index(conn, _params) do
    users = Repo.all User
    render(conn, "index.json", users: users)
  end
end
