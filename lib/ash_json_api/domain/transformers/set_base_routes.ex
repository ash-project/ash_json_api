# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Domain.Transformers.SetBaseRoutes do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl) do
    dsl
    |> AshJsonApi.Domain.Info.routes()
    |> flatten_base_routes(Spark.Dsl.Transformer.get_persisted(dsl, :module))
    |> case do
      [] ->
        {:ok, dsl}

      routes ->
        {:ok, put_in(dsl, [[:json_api, :routes], :entities], routes)}
    end
  end

  def before?(_), do: true

  defp flatten_base_routes(routes, module, root \\ nil, resource \\ nil) do
    Enum.flat_map(routes, fn
      %AshJsonApi.Domain.BaseRoute{route: prefix, routes: more_routes} = base ->
        prefix =
          case root do
            nil -> String.trim_leading(prefix, "/")
            root -> Path.join(root, String.trim_leading(prefix, "/"))
          end

        more_routes
        |> Enum.map(fn
          %AshJsonApi.Resource.Route{} = route ->
            resource = route.resource || base.resource || resource

            if !resource do
              raise Spark.Error.DslError,
                module: module,
                path: [:routes, :base_route, prefix, route.type],
                message: """
                Could not determine resource for route. It must be specified on the base route or the route itself.
                """
            end

            new_route =
              if prefix == "" do
                "/" <> String.trim_leading(route.route, "/")
              else
                "/" <>
                  prefix <>
                  "/" <> String.trim_leading(route.route, "/")
              end

            new_route = String.trim_trailing(new_route, "/")

            %{route | route: new_route, resource: resource}

          %AshJsonApi.Domain.BaseRoute{} = base ->
            base
        end)
        |> flatten_base_routes(module, prefix, base.resource)

      route ->
        [route]
    end)
  end
end
