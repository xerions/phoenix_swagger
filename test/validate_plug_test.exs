defmodule ValidatePlugTest do
  use ExUnit.Case
  use Plug.Test
  require IEx

  alias PhoenixSwagger.Plug.Validate
  alias PhoenixSwagger.Validator
  alias Plug.Conn

  @table :validator_table

  setup do
    schema = Validator.parse_swagger_schema(["test/test_spec/swagger_test_spec.json", "test/test_spec/swagger_test_spec_2.json", "test/test_spec/swagger_test_spec_3.json"])
    on_exit fn ->
      :ets.delete_all_objects(@table)
    end
    {:ok, schema}
  end

  test "init" do
    opts = [foo: :bar, bar: 123]
    assert opts == Validate.init(opts)
  end

  test "validation successful on a valid request" do
    test_conn = init_conn(:get, "/api/pets")
    test_conn = Validate.call(test_conn, [])
    assert is_nil test_conn.status
    assert is_nil test_conn.resp_body
    assert test_conn.private[:phoenix_swagger][:valid]
  end

  test "validation fails on an invalid request" do
    test_conn = init_conn(:post, "/v1/products", %{foo: :bar})
    test_conn = Validate.call(test_conn, [])
    assert {400, _, _} = sent_resp(test_conn)
  end

  test "validation fails on an invalid path" do
    test_conn = init_conn(:get, "foo", %{foo: :bar})
    test_conn = Validate.call(test_conn, [])
    assert {404, _, _} = sent_resp(test_conn)
  end

  test "validation fails with custom code" do
    test_conn = init_conn(:post, "/v1/products", %{foo: :bar})
    test_conn = Validate.call(test_conn, [validation_failed_status: 422])
    assert {422, _, _} = sent_resp(test_conn)
  end

  test "validation skipped if valid flag is already set" do
    test_conn = init_conn(:get, "foo", %{foo: :bar})
    test_conn = Conn.put_private(test_conn, :phoenix_swagger, %{valid: true})
    assert test_conn == Validate.call(test_conn, [])
  end

  test "validation successful on a valid request with array query param" do
    test_conn = init_conn(:get, "/api/pets", %{}, %{"tags" => "cats,dogs"})
    test_conn = Validate.call(test_conn, [])
    assert is_nil test_conn.status
    assert is_nil test_conn.resp_body
    assert test_conn.private[:phoenix_swagger][:valid]
  end

  test "validation successful on a valid request with query enum param" do
    test_conn = init_conn(:get, "/api/pets", %{}, %{"size" => "medium", "class" => "fish,birds", "tags" => "predator"})
    test_conn = Validate.call(test_conn, [])
    assert is_nil test_conn.status
    assert is_nil test_conn.resp_body
    assert test_conn.private[:phoenix_swagger][:valid]
  end

  test "validation fails if query array param elem is not allowed in enum" do
    test_conn = init_conn(:get, "/api/pets", %{}, %{"class" => "fish,birds,cats"})
    test_conn = Validate.call(test_conn, [])
    {400, _, body} = sent_resp(test_conn)
    expected_body = [
      ~S({"error":{"path":"#/class","message":"Value \"cats\" is not allowed in enum."}}),
      ~S({"error":{"message":"Value \"cats\" is not allowed in enum.","path":"#/class"}})
    ]
    assert Enum.member?(expected_body, body)
  end

  test "validation fails if query param value is not allowed in enum" do
    test_conn = init_conn(:get, "/api/pets", %{}, %{"size" => "extra-big"})
    test_conn = Validate.call(test_conn, [])
    {400, _, body} = sent_resp(test_conn)
    expected_body = [
      ~S({"error":{"path":"#/size","message":"Value \"extra-big\" is not allowed in enum."}}),
      ~S({"error":{"message":"Value \"extra-big\" is not allowed in enum.","path":"#/size"}})
    ]
    assert Enum.member?(expected_body, body)
  end

  test "validation matches specific route before templated route" do
    test_conn = init_conn(:get, "/api/pets/cats", %{}, %{})
    test_conn = Validate.call(test_conn, [])
    assert is_nil test_conn.status
    assert is_nil test_conn.resp_body
    assert test_conn.private[:phoenix_swagger][:valid]
  end

  defp init_conn(verb, path, body_params \\ %{}, path_params \\ %{}) do
    conn(verb, path)
    |> Map.put(:body_params, body_params)
    |> Map.put(:path_params, path_params)
    |> Map.put(:params, Map.merge(path_params, body_params))
    |> Conn.fetch_query_params
  end
end
