defmodule AshJsonApi.Resource.Verifiers.VerifyQueryParams do
  @moduledoc "Verify query params are not reserved or shadowed by the route"
  use Spark.Dsl.Verifier

  @reserved_query_param_names [
    :fields,
    :field_inputs,
    :filter_included,
    :include,
    :page
  ]

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)

    dsl
    |> AshJsonApi.Domain.Info.routes()
    |> Enum.each(&verify_route!(&1, module))

    :ok
  end

  @doc false
  def verify_route!(route, module) do
    route_params =
      route.route
      |> Path.split()
      |> Enum.filter(&String.starts_with?(&1, ":"))
      |> Enum.map(&String.trim_leading(&1, ":"))

    route.query_params
    |> Enum.each(fn query_param ->
      if query_param in @reserved_query_param_names do
        raise Spark.Error.DslError,
          module: module,
          path: [:json_api, :routes, route.type, route.action],
          message: """
          Cannot accept #{query_param} as a query parameter because it is reserved.

          Reserved names:
          #{@reserved_query_param_names |> Enum.join(", ")}
          """
      end

      if to_string(query_param) in route_params do
        raise Spark.Error.DslError,
          module: module,
          path: [:json_api, :routes, route.type, route.action],
          message: """
          Cannot accept #{query_param} as a query parameter because it is also a parameter in the path.
          """
      end
    end)
  end
end
