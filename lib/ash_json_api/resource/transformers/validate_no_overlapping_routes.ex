defmodule AshJsonApi.Resource.Transformers.ValidateNoOverlappingRoutes do
  @moduledoc "Validates that all method/route combinations are unique"
  use Ash.Dsl.Transformer

  def transform(resource, dsl) do
    resource
    |> AshJsonApi.Resource.routes()
    |> Enum.group_by(fn route ->
      {route.method, route.route}
    end)
    |> Enum.reduce_while({:ok, dsl}, fn {{method, route}, group}, {:ok, dsl} ->
      case group do
        [_route] ->
          {:cont, {:ok, dsl}}

        _ ->
          {:halt, {:error, "Duplicate routes defined for #{method}: #{route}"}}
      end
    end)
  end
end
