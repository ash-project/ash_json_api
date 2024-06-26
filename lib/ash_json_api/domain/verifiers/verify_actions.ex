defmodule AshJsonApi.Domain.Verifiers.VerifyActions do
  @moduledoc "Verifies that all actions are valid for each route."
  use Spark.Dsl.Verifier

  @compatible_action_types AshJsonApi.Resource.Verifiers.VerifyActions.compatible_action_types()

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)

    dsl
    |> AshJsonApi.Domain.Info.routes()
    |> Enum.each(fn route ->
      resource = route.resource

      action =
        if route.action do
          Ash.Resource.Info.action(resource, route.action)
        else
          route.action_type && Ash.Resource.Info.primary_action!(resource, route.action_type)
        end

      if !action do
        raise Spark.Error.DslError,
          module: module,
          path: [:json_api, :routes, route.type, route.action],
          message: """
          Unknown action specified: #{inspect(route.action)}
          """
      end

      valid_action_types = List.wrap(@compatible_action_types[route.type])

      unless action.type in valid_action_types do
        raise Spark.Error.DslError,
          module: module,
          path: [:json_api, :routes, route.type, route.action],
          message: """
          Unsupported action type for route type #{inspect(route.type)}.

          Got: #{inspect(action.type)}
          Allowed: #{inspect(valid_action_types)}
          """
      end

      if action.type == :action do
        AshJsonApi.Resource.Verifiers.VerifyActions.verify_return_type!(
          module,
          resource,
          route,
          action
        )
      end
    end)

    :ok
  end
end
