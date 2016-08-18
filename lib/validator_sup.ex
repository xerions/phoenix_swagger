defmodule PhoenixSwagger.Validator.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: TableOwnerSup])
  end

  def init([]) do
    children = [
      worker(PhoenixSwagger.Validator.TableOwner, [name: PhoenixSwagger.Validator.TableOwner])
    ]
    # supervise/2 is imported from Supervisor.Spec
    supervise(children, [strategy: :one_for_one, name: A])
  end
end
