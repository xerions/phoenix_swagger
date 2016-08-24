defmodule ValidatorTest do
  use ExUnit.Case

  alias PhoenixSwagger.Validator

  @table :validator_table

  setup do
    schema = Validator.parse_swagger_schema("test/test_spec/swagger_test_spec.json")
    on_exit fn ->
      :ets.delete_all_objects(@table)
    end
    {:ok, schema}
  end

  test "parse_swagger_schema() test", schemas do
    price = schemas["/get/estimates/price"].schema["properties"]
    time = schemas["/get/estimates/time"].schema["properties"]
    history = schemas["/get/history"].schema["properties"]
    products_post = schemas["/post/products"].schema["properties"]
    products_get = schemas["/get/products"].schema["properties"]

    assert %{"end_latitude" => %{"type" => "integer"},
             "end_longitude" => %{"type" => "integer"},
             "start_latitude" => %{"type" => "integer"},
             "start_longitude" => %{"type" => "integer"}} = price
    assert %{"customer_uuid" => %{"type" => "string"},
             "product_id" => %{"type" => "string"},
             "start_latitude" => %{"type" => "integer"},
             "start_longitude" => %{"type" => "integer"}} = time
    assert %{"limit" => %{"type" => "integer"},
             "offset" => %{"type" => "integer"}} = history
    assert %{"latitude" => %{"type" => "integer"},
             "longitude" => %{"type" => "integer"}} = products_get
    assert %{"latitude" => %{"type" => "integer"},
             "longitude" => %{"type" => "integer"},
             "ID" => %{"type" => "integer"}} = products_post
  end

  test "validate() test" do
    assert {:error,"Type mismatch. Expected Integer but got String.",
            "#/limit"} = Validator.validate("/get/history", %{"limit" => "10"})
    assert {:error,"Type mismatch. Expected Integer but got String.",
            "#/offset"} = Validator.validate("/get/history", %{"limit" => 10, "offset" => "100"})
    assert :ok = Validator.validate("/get/history", %{"limit" => 10, "offset" => 100})
		assert {:error, :resource_not_exists} = Validator.validate("/wrong_path", %{})
  end
end
