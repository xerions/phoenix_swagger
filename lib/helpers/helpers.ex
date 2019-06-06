defmodule PhoenixSwagger.Helpers do

  def merge_definitions(definitions, swagger_map = %{definitions: existing}) do
    %{swagger_map | definitions: Map.merge(existing, definitions)}
  end

  def merge_paths(path, swagger_map) do
    paths = Map.merge(swagger_map.paths, path, &merge_conflicts/3)
    %{swagger_map | paths: paths}
  end

  def swagger_map(swagger_map) do
    Map.update(swagger_map, :definitions, %{}, &(&1))
    |> Map.update(:paths, %{}, &(&1))
  end

  def extract_args(action) do
    [
      %{verb: action |> String.to_atom, path: ""}
    ]
  end

  defp merge_conflicts(_key, value1, value2) do
    Map.merge(value1, value2)
  end

end
