defmodule Simple.Router do
  use Simple.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", Simple do
    pipe_through :api
    resources "/users", UserController, except: [:new, :edit]
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :simple, swagger_file: "swagger.json"
  end

  def swagger_info do
    %{
      info: %{
        version: "1.0",
        title: "Simple App"
      }
    }
  end
end
