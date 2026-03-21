# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Resource.Verifiers.VerifyRelationships do
  @moduledoc "Verifies that any routes that reference a relationship reference a public one"
  use Spark.Dsl.Verifier

  def verify(dsl) do
    resource = Spark.Dsl.Verifier.get_persisted(dsl, :module)

    dsl
    |> AshJsonApi.Resource.Info.routes()
    |> Enum.each(fn route ->
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

    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.each(fn relationship ->
      destination = relationship.destination

      if AshJsonApi.Resource in Spark.extensions(destination) do
        read_action =
          if relationship.read_action do
            Ash.Resource.Info.action(destination, relationship.read_action)
          else
            Ash.Resource.Info.primary_action(destination, :read)
          end

        if read_action && !Map.get(read_action, :public?, true) do
          raise Spark.Error.DslError,
            module: resource,
            path: [:json_api],
            message: """
            Relationship #{inspect(resource)}.#{relationship.name} points to \
            #{inspect(destination)}, whose read action #{inspect(read_action.name)} is not `public?`.

            Public relationships on JSON:API resources must have `public?` read actions \
            on their destination resources.
            """
        end
      end
    end)

    :ok
  end
end
