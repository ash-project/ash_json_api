defmodule AshJsonApi.Resource.Transformers.ValidateNoOverlappingRoutes do
  @moduledoc "Validates that all method/route combinations are unique"
  use Ash.Dsl.Transformer

  alias Ash.Dsl.Transformer

  @extension AshJsonApi.Resource

  def transform(_resource, dsl) do
    dsl
    |> Transformer.get_entities([:json_api, :routes], @extension)
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
