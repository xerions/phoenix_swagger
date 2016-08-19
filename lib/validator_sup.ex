defmodule PhoenixSwagger.Validator.Supervisor do
  use Supervisor

  def start_link(swagger_schema_path) do
    Supervisor.start_link(__MODULE__, [swagger_schema_path], [name: TableOwnerSup])
  end

  def init([swagger_schema_path]) do
    children = [
      worker(PhoenixSwagger.Validator.TableOwner, [swagger_schema_path], [name: PhoenixSwagger.Validator.TableOwner])
    ]
    # supervise/2 is imported from Supervisor.Spec
    supervise(children, [strategy: :one_for_one])
  end
end
