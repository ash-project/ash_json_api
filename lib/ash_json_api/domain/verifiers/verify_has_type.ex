defmodule AshJsonApi.Domain.Verifiers.VerifyHasType do
  @moduledoc "Verifies that a resource has a type if it has any routes that need it."
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    dsl
    |> AshJsonApi.Resource.Info.routes()
    |> Enum.group_by(& &1.resource)
    |> Enum.each(fn {resource, routes} ->
      has_non_generic_action_route? =
        Enum.any?(routes, &(&1.type != :route))

      if has_non_generic_action_route? && is_nil(AshJsonApi.Resource.Info.type(resource)) do
        raise Spark.Error.DslError,
          module: resource,
          path: [:json_api, :type],
          message: """
          `json_api.type` is required.

          For example:

          json_api do
            type "your_type"
          end
          """
      end
    end)

    :ok
  end
end
