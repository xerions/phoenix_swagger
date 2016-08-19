defmodule PhoenixSwagger.Validator.TableOwner do
  use GenServer
  alias PhoenixSwagger.Validator

  @table :validator_table

  def start_link(schema_path) do
    GenServer.start_link(__MODULE__, schema_path, [name: TableOwner])
  end

  def init(args) do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:public,:named_table])
        @table
      _ ->
        # no need to create validator table if we already have it
        @table
    end
    Validator.parse_swagger_schema(args)
    {:ok, %{}}
  end

  def handle_call({:lookup, path}, _from, t) do
    {:reply, :ets.lookup(:validator_table, path), t}
  end

  def handle_cast({:insert, path, schema}, t) do
    :ets.insert(@table, {path, schema})
    {:noreply, t}
  end
end
