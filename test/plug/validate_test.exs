defmodule PhoenixSwagger.Plug.ValidateTest do
  use ExUnit.Case
  use Plug.Test

  alias PhoenixSwagger.{Plug.Validate, Validator}
  alias Plug.Conn

  @opts Validate.init([])
  @parsers_opts Plug.Parsers.init(json_decoder: Poison, parsers: [:urlencoded, :json], pass: ["*/*"])
  @table :validator_table

  setup do
    Validator.parse_swagger_schema(["test/test_spec/swagger_jsonapi_test_spec.json"])

    on_exit fn ->
      :ets.delete_all_objects(@table)
    end

    :ok
  end

  test "required param returns error when not present" do
    conn = :get
           |> conn("/shapes?filter[route]=Red")
           |> put_req_header("request-id", "d92578b3-d281-48a8-9e91-32b276fe6458")
           |> parse()
    assert %Conn{halted: true, resp_body: body, status: 400} = Validate.call(conn, @opts)
    assert Poison.decode!(body) == %{
             "error" => %{
               "message" => "Required property api_key was not present.",
               "path" => "#"
             }
           }
  end

  test "required nested param returns error when not present" do
    conn = :get
           |> conn("/shapes?api_key=SECRET")
           |> put_req_header("request-id", "d92578b3-d281-48a8-9e91-32b276fe6458")
           |> parse()
    assert %Conn{halted: true, resp_body: body, status: 400} = Validate.call(conn, @opts)
    assert Poison.decode!(body) == %{
             "error" => %{
               "message" => "Required property filter[route] was not present.",
               "path" => "#"
             }
           }
  end

  test "required header returns error when not present" do
    conn = :get
           |> conn("/shapes?filter[route]=Red")
           |> parse()
    assert %Conn{halted: true, resp_body: body, status: 400} = Validate.call(conn, @opts)
    assert Poison.decode!(body) == %{
             "error" => %{
               "message" => "Required header request-id was not present.",
               "path" => "#"
             }
           }
  end

  test "does not halt when required params present" do
    conn = :get
           |> conn("/shapes?api_key=SECRET&filter[route]=Red")
           |> put_req_header("request-id", "d92578b3-d281-48a8-9e91-32b276fe6458")
           |> parse()
    assert %Conn{halted: false} = Validate.call(conn, @opts)
  end

  defp parse(conn), do: Plug.Parsers.call(conn, @parsers_opts)
end
