# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Resource.Verifiers.VerifyHasType do
  @moduledoc "Verifies that a resource has a type if it has any routes that need it."
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)

    has_non_generic_action_route? =
      dsl
      |> AshJsonApi.Resource.Info.routes()
      |> Enum.any?(&(&1.type != :route))

    if has_non_generic_action_route? && is_nil(AshJsonApi.Resource.Info.type(dsl)) do
      raise Spark.Error.DslError,
        module: module,
        path: [:json_api, :type],
        message: """
        `json_api.type` is required.

        For example:

        json_api do
          type "your_type"
        end
        """
    end

    :ok
  end
end
