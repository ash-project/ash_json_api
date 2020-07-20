defmodule AshJsonApi.Resource.Transformers.PrependRoutePrefix do
  @moduledoc "Ensures that the `base` route is prepended to each route"
  use Ash.Dsl.Transformer

  alias Ash.Dsl.Transformer

  def transform(resource, dsl) do
    prefix = AshJsonApi.Resource.base_route(resource)

    resource
    |> AshJsonApi.Resource.routes()
    |> Enum.reduce({:ok, dsl}, fn route, {:ok, dsl} ->
      new_route =
        "/" <>
          String.trim_leading(prefix, "/") <> "/" <> String.trim_leading(route.route, "/")

      new_route = String.trim_trailing(new_route, "/")

      new_dsl =
        Transformer.replace_entity(
          dsl,
          [:json_api, :routes],
          %{route | route: new_route},
          fn replacing_route ->
            replacing_route.method == route.method && replacing_route.route == route.route
          end
        )

      {:ok, new_dsl}
    end)
  end
end
