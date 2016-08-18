defmodule ValidatorTest do
  use ExUnit.Case

  alias PhoenixSwagger.Validator

  setup do
    schema = Validator.parse_swagger_schema("test/test_spec/swagger_test_spec.json")
    on_exit fn ->
      [child_id] = Supervisor.which_children(TableOwnerSup)
      Supervisor.terminate_child(TableOwnerSup, child_id)
    end
    {:ok, schema}
  end

  test "parse_swagger_schema() test", schemas do
    price = schemas["/estimates/price"].schema["properties"]
    time = schemas["/estimates/time"].schema["properties"]
    history = schemas["/history"].schema["properties"]
    products = schemas["/products"].schema["properties"]

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
             "longitude" => %{"type" => "integer"}} = products
  end

  test "validate() test" do
    assert {:error,"Type mismatch. Expected Integer but got String.",
            "#/limit"} = Validator.validate("/history", %{"limit" => "10"})
    assert {:error,"Type mismatch. Expected Integer but got String.",
            "#/offset"} = Validator.validate("/history", %{"limit" => 10, "offset" => "100"})
    assert :ok = Validator.validate("/history", %{"limit" => 10, "offset" => 100})
  end
end
