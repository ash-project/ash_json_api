defmodule AshJsonApi.Domain.Verifiers.VerifyRelationships do
  @moduledoc "Verifies that any routes that reference a relationship reference a public one"
  use Spark.Dsl.Verifier

  def verify(dsl) do
    dsl
    |> AshJsonApi.Resource.Info.routes()
    |> Enum.each(fn route ->
      resource = route.resource

      if route.relationship do
        relationship = Ash.Resource.Info.relationship(resource, route.relationship)

        if !relationship do
          raise Spark.Error.DslError,
            module: resource,
            path: [:json_api, :routes, route.type],
            message: """
            No such relationship #{inspect(resource)}.#{route.relationship}
            """
        end

        if !relationship.public? do
          raise Spark.Error.DslError,
            module: resource,
            path: [:json_api, :routes, route.type],
            message: """
            Relationship #{inspect(resource)}.#{route.relationship} is not `public?`.

            Only `public?` relationship can be used in AshJsonApi routes.
            """
        end
      end
    end)

    :ok
  end
end
