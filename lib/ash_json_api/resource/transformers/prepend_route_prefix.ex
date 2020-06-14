defmodule AshJsonApi.Resource.Transformers.PrependRoutePrefix do
  @moduledoc "Ensures that the `base` route is prepended to each route"
  use Ash.Dsl.Transformer

  alias Ash.Dsl.Transformer

  @extension AshJsonApi.Resource

  def transform(resource, dsl) do
    prefix = AshJsonApi.base_route(resource)

    dsl
    |> Transformer.get_entities([:json_api, :routes], @extension)
    |> Enum.reduce({:ok, dsl}, fn route, {:ok, dsl} ->
      new_route =
        "/" <>
          String.trim_leading(prefix, "/") <> "/" <> String.trim_leading(route.route, "/")

      new_route = String.trim_trailing(new_route, "/")

      new_dsl =
        Transformer.replace_entity(
          dsl,
          [:json_api, :routes],
          @extension,
          %{route | route: new_route},
          fn replacing_route ->
            replacing_route.method == route.method && replacing_route.route == route.route
          end
        )

      {:ok, new_dsl}
    end)
  end
end
