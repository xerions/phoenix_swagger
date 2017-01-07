defmodule PhoenixSwaggerTest do
  use ExUnit.Case
  doctest PhoenixSwagger

  use PhoenixSwagger

  @description "Some description"
  @response "Some response description"
  @schema %{
      title: "User",
      type: :object,
      properties: %{name: %{type: :string}}
    }

  swagger_model :users do
    description @description
    responses 200, @response
  end

  swagger_model :user do
    description @description
    parameter :body, :body, @schema, @description
    responses 200, @response
  end

  test "tag matches with module" do
    {[description], _parameters, [tag], response_code,
     response_description, _meta} = swagger_users()
    assert @description == description
    assert "PhoenixSwaggerTest" == tag
    assert 200 == response_code
    assert @response == response_description
  end

  test "parameter as swagger object" do
    {_desc, [parameter], _tags, _code, _resp, _meta} = swagger_user()
    assert {:param, [in: :body, name: :body, schema: @schema, required: false, description: @description]} == parameter
  end
end
