defmodule AshJsonApi.Resource.Verifiers.VerifyActions do
  @moduledoc "Verifies that all actions are valid for each route."
  use Spark.Dsl.Verifier

  @compatible_action_types [
    get: [:read, :action],
    index: [:read, :action],
    post: [:create, :action],
    patch: [:update, :action],
    delete: [:destroy, :action],
    route: [:action],
    get_related: [:read],
    relationship: [:read],
    post_to_relationship: [:update],
    patch_relationship: [:update],
    delete_from_relationship: [:update]
  ]

  @doc false
  def compatible_action_types, do: @compatible_action_types

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)

    dsl
    |> AshJsonApi.Resource.Info.routes()
    |> Enum.each(fn route ->
      action =
        if route.action do
          Ash.Resource.Info.action(dsl, route.action)
        else
          route.action_type && Ash.Resource.Info.primary_action!(dsl, route.action_type)
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
        verify_return_type!(module, module, route, action)
      end
    end)

    :ok
  end

  @doc false
  def verify_return_type!(module, resource, route, action) do
    case route.type do
      :route ->
        :ok

      :index ->
        needed_type = "{:array, :struct}"
        needed_constraints = "items: [instance_of: #{inspect(resource)}]"

        case action.returns do
          {:array, value} ->
            {type, constraints} = flatten_new_type(value, action.constraints[:items] || [])

            unless type == Ash.Type.Struct && constraints[:instance_of] == resource do
              invalid_return_type!(module, route, action, needed_type, needed_constraints)
            end

          _ ->
            invalid_return_type!(module, route, action, needed_type, needed_constraints)
        end

      type when type in [:get, :post] ->
        needed_type = ":struct"
        needed_constraints = "instance_of: #{inspect(resource)}"

        {type, constraints} = flatten_new_type(action.returns, action.constraints || [])

        unless type == Ash.Type.Struct && constraints[:instance_of] == resource do
          invalid_return_type!(module, route, action, needed_type, needed_constraints)
        end

      type when type in [:patch, :delete] ->
        argument_names = Enum.map(action.arguments, &to_string(&1.name))

        path_params =
          route.route
          |> Path.split()
          |> Enum.filter(&String.starts_with?(&1, ":"))
          |> Enum.map(&String.trim(String.trim_leading(&1, ":")))
          |> Enum.uniq()

        path_params
        |> Kernel.--(argument_names)
        |> case do
          [] ->
            :ok

          missing_arguments ->
            raise Spark.Error.DslError,
              module: module,
              path: [:json_api, :routes, route.type, route.action],
              message: """
              Generic action #{inspect(action.name)} does not have corresponding arguments for all of its path params:

              Route: #{route.route}

              Path Params: #{inspect(path_params)}

              Missing: #{inspect(missing_arguments)}
              """
        end

        needed_type = ":struct"
        needed_constraints = "instance_of: #{inspect(resource)}"

        {type, constraints} = flatten_new_type(action.returns, action.constraints || [])

        unless type == Ash.Type.Struct && constraints[:instance_of] == resource do
          invalid_return_type!(module, route, action, needed_type, needed_constraints)
        end
    end

    :ok
  end

  defp invalid_return_type!(module, route, action, needed_type, constraints) do
    raise Spark.Error.DslError,
      module: module,
      path: [:json_api, :routes, route.type, route.action],
      message: """
      Invalid return type for generic action used in #{route.type} route.

      Expected type `#{needed_type}`
      Expected constraints: #{constraints}

      Got type: #{inspect(action.returns)}
      Got constraints: #{inspect(action.constraints)}
      """
  end

  defp flatten_new_type(type, constraints) do
    if Ash.Type.NewType.new_type?(type) do
      new_constraints = Ash.Type.NewType.constraints(type, constraints)
      new_type = Ash.Type.NewType.subtype_of(type)

      {new_type, new_constraints}
    else
      {type, constraints}
    end
  end
end
