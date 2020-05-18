defmodule SimpleWeb.Helpers.CommonSchemas do
  use PhoenixSwagger

  def swagger_definitions do
    %{
      Error:
        swagger_schema do
          title("Error")
          description("An error response")

          properties do
            success(:boolean, "Success bool")
            msg(:string, "Error response", required: true)
          end

          example(%{
            success: false,
            msg: "User ID missing"
          })
        end
      }
    end

end
