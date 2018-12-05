defmodule SimpleWeb.Router do
  use SimpleWeb, :router
  alias PhoenixSwagger.Plug.Validate

  pipeline :api do
    plug(:accepts, ["json"])
    plug(Validate, validation_failed_status: 422)
  end

  scope "/api", SimpleWeb do
    pipe_through(:api)
    resources("/users", UserController, except: [:new, :edit])
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :simple, swagger_file: "swagger.json")
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
