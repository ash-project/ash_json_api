defmodule AshJsonApi.Domain.Transformers.SetBaseRoutes do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl) do
    dsl
    |> AshJsonApi.Domain.Info.routes()
    |> Enum.flat_map(fn
      %AshJsonApi.Domain.BaseRoute{route: prefix, routes: routes} = base ->
        prefix = String.trim_leading(prefix, "/")

        Enum.map(routes, fn
          route ->
            resource = route.resource || base.resource

            if !resource do
              raise Spark.Error.DslError,
                module: Spark.Dsl.Transformer.get_persisted(dsl, :module),
                path: [:routes, :base_route, prefix, route.type],
                message: """
                Could not determine resource for route. It must be specified on the base route or the route itself.
                """
            end

            new_route =
              "/" <>
                prefix <>
                "/" <> String.trim_leading(route.route, "/")

            new_route = String.trim_trailing(new_route, "/")

            %{route | route: new_route, resource: resource}
        end)

      route ->
        [route]
    end)
    |> case do
      [] ->
        {:ok, dsl}

      routes ->
        {:ok, put_in(dsl, [[:json_api, :routes], :entities], routes)}
    end
  end

  def before?(_), do: true
end
