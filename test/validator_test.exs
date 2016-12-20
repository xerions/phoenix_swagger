defmodule ValidatorTest do
  use ExUnit.Case

  alias PhoenixSwagger.Validator

  @table :validator_table

  setup do
    schema = Validator.parse_swagger_schema(["test/test_spec/swagger_test_spec.json", "test/test_spec/swagger_test_spec_2.json"])
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

    pets_get = schemas["/get/pets"].schema["properties"]
    pets_post =  schemas["/post/pets"].schema["properties"]
    pet_id = schemas["/get/pets/{id}"].schema["properties"]
    pet_delete = schemas["/delete/pets/{id}"].schema["properties"]

    assert %{"tags" => %{"type" => "array"},
             "limit" => %{"type" => "integer"}} = pets_get
    assert %{"id"  => %{"format" => "int64", "type" => "integer"},
             "pet" => %{"$ref" => [:root, "definitions", "Pet"]}} = pets_post
    assert %{"id" => %{"type" => "integer"}} = pet_id
    assert %{"id" => %{"type" => "integer"}} = pet_delete
  end

  test "validate() test" do
    assert {:error,"Type mismatch. Expected Integer but got String.",
            "#/limit"} = Validator.validate("/get/history", %{"limit" => "10"})
    assert {:error,"Type mismatch. Expected Integer but got String.",
            "#/offset"} = Validator.validate("/get/history", %{"limit" => 10, "offset" => "100"})
    assert :ok = Validator.validate("/get/history", %{"limit" => 10, "offset" => 100})
    assert {:error, :resource_not_exists} = Validator.validate("/wrong_path", %{})
    assert :ok = Validator.validate("/get/estimates/time", %{"start_latitude" => 10, "start_longitude" => 20})
    assert {:error, "Type mismatch. Expected Integer but got String.", "#/id"} = Validator.validate("/get/pets/{id}", %{"id" => "1"})
    assert {:error, :resource_not_exists} = Validator.validate("/get/pets/id", %{"id" => "1"})
    assert :ok = Validator.validate("/get/pets/{id}", %{"id" => 1})
    assert {:error, :resource_not_exists} = Validator.validate("/pets", %{"id" => 1})
    assert {:error,
            [{"Required property id was not present.", "#"},
             {"Required property pet was not present.", "#"}], "/post/pets"} = Validator.validate("/post/pets", %{})
    assert {:error,
            [{"Type mismatch. Expected Integer but got String.", "#/id"},
             {"Required property pet was not present.", "#"}], "/post/pets"} = Validator.validate("/post/pets", %{"id" => "wrong_id"})
    assert {:error, "Required property pet was not present.", "#"} = Validator.validate("/post/pets", %{"id" => 1})
    assert {:error,
            [{"Required property name was not present.", "#/pet"},
             {"Required property tag was not present.", "#/pet"}], "/post/pets"}
      = Validator.validate("/post/pets", %{"id" => 1, "pet" => %{}})
    assert {:error, "Required property tag was not present.", "#/pet"}
      = Validator.validate("/post/pets", %{"id" => 1, "pet" => %{"name" => "pet_name"}})
    assert :ok = Validator.validate("/post/pets", %{"id" => 1, "pet" => %{"name" => "pet_name", "tag" => "pet_tag"}})
  end
end
