defmodule AshJsonApi.Domain.Transformers.SetBaseRoutes do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl) do
    dsl
    |> AshJsonApi.Domain.Info.routes()
    |> Enum.flat_map(fn
      %AshJsonApi.Domain.BaseRoute{route: prefix, routes: routes} ->
        prefix = String.trim_leading(prefix, "/")

        Enum.map(routes, fn
          route ->
            new_route =
              "/" <>
                prefix <>
                "/" <> String.trim_leading(route.route, "/")

            new_route = String.trim_trailing(new_route, "/")

            %{route | route: new_route}
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
