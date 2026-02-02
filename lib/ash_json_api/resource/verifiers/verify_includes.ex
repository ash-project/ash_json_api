# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Resource.Verifiers.VerifyIncludes do
  @moduledoc "Verifies that all includes are valid public relationships"
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    AshJsonApi.Resource.Info.includes(dsl)
    |> verify_includes(Spark.Dsl.Verifier.get_persisted(dsl, :module))

    :ok
  end

  defp verify_includes(includes, resource, root_resource \\ nil, trail \\ [])

  defp verify_includes(includes, resource, nil, trail) do
    verify_includes(includes, resource, resource, trail)
  end

  defp verify_includes([], _resource, _root, _trail), do: :ok

  defp verify_includes(includes, resource, root, trail) when is_list(includes) do
    Enum.each(includes, &verify_includes(&1, resource, root, trail))
  end

  defp verify_includes(include, resource, root, trail) when is_atom(include) do
    relationship = Ash.Resource.Info.relationship(resource, include)

    if !relationship do
      raise Spark.Error.DslError,
        module: root,
        path: [:json_api, :includes] ++ Enum.reverse(trail) ++ [include],
        message: """
        All includable relationships must be valid relationships.

        There is no such relationship `#{inspect(resource)}.#{include}`
        """
    end

    if !relationship.public? do
      raise Spark.Error.DslError,
        module: root,
        path: [:json_api, :includes] ++ Enum.reverse(trail) ++ [include],
        message: """
        All includable relationships must be public.

        The relationship `#{inspect(resource)}.#{include}` is not public.
        """
    end
  end

  defp verify_includes({include, further}, resource, root, trail) when is_atom(include) do
    verify_includes(include, resource, root, trail)
    relationship = Ash.Resource.Info.relationship(resource, include)

    Enum.each(List.wrap(further), fn further ->
      verify_includes(further, relationship.destination, root, [include | trail])
    end)
  end
end
