defmodule AshJsonApi do
  def route(resource, criteria \\ %{}) do
    resource
    |> routes()
    |> Enum.find(fn route ->
      Map.take(route, Map.keys(criteria)) == criteria
    end)
  end

  def join_fields(resource, association) do
    join_fields(resource)[association]
  end

  def join_fields(resource) do
    resource.json_api_join_fields()
  end

  def routes(resource) do
    resource.json_api_routes()
  end

  def fields(resource) do
    resource.json_api_fields()
  end

  def includes(resource) do
    resource.json_api_includes()
  end

  def host(api) do
    api.host()
  end

  def prefix(api) do
    api.prefix()
  end

  def serve_schema(api) do
    api.serve_schema()
  end

  @doc false
  # TODO: Remember why you wrote this and make sure it does what you thought it did then
  def sanitize_routes(_relationships, all_routes) do
    all_routes
    |> Enum.group_by(fn route ->
      {route.method, route.route}
    end)
    |> Enum.flat_map(fn {{method, route}, group} ->
      case group do
        [route] ->
          [route]

        _ ->
          raise "Duplicate routes defined for #{method}: #{route}"
      end
    end)

    # |> Enum.reject(&pruned?(relationships, &1))
    # |> Enum.reject(&is_nil(&1.relationship))
    # |> Enum.group_by(&Map.take(&1, [:action, :relationship]))
    # |> Enum.flat_map(fn {info, routes} ->
    #   case routes do
    #     [route] ->
    #       [%{route | primary?: true}]

    #     routes ->
    #       case Enum.count(routes, & &1.primary?) do
    #         0 ->
    #           # TODO: Format these prettier
    #           raise "Must declare a primary route for #{format_action(info)}, as there are more than one."

    #         1 ->
    #           routes

    #         _ ->
    #           raise "Duplicate primary routes declared for #{format_action(info)}, but there can only be one primary route."
    #       end
    #   end
    # end)

    # defp pruned?(_relationships, %{prune: nil}), do: false

    # defp pruned?(relationships, %{
    #        prune: {:require_relationship_cardinality, :many},
    #        relationship: relationship_name
    #      }) do
    #   relationship =
    #     Enum.find(relationships, fn relationship ->
    #       relationship.name == relationship_name
    #     end)

    #   match?(%{cardinality: cardinality} when cardinality != :many, relationship)
    # end

    # defp format_action(%{action: action, relationship: nil}), do: "`#{action}`"

    # defp format_action(%{action: action, relationship: relationship}),
    #   do: "`#{action}`: `#{relationship}`"
  end
end
