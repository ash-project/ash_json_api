defmodule AshJsonApi.Resource.Transformers.PrependRoutePrefix do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl) do
    prefix = Transformer.get_option(dsl, [:json_api, :routes], :base)

    dsl
    |> Transformer.get_entities([:json_api, :routes])
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
