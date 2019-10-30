defmodule AshJsonApi do
  # Honestly, at some point json api should probably be its own thing

  defmacro __using__(_) do
    quote do
      import AshJsonApi.JsonApi, only: [json_api: 1]
      Module.register_attribute(__MODULE__, :json_api_routes, accumulate: true)
      Module.register_attribute(__MODULE__, :json_api_fields, accumulate: true)

      @json_api_includes []
      @mix_ins AshJsonApi
      require AshJsonApi
    end
  end

  @doc false
  def before_compile_hook(_env) do
    quote do
      @json_api_routes AshJsonApi.mark_primaries(@json_api_routes)

      def json_api_routes() do
        @json_api_routes
      end

      def json_api_fields() do
        @json_api_fields
      end

      def json_api_includes() do
        @json_api_includes
      end
    end
  end

  def route(resource, criteria \\ %{}) do
    resource
    |> routes()
    |> Enum.find(fn route ->
      Map.take(route, Map.keys(criteria)) == criteria
    end)
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

  @doc false
  def mark_primaries(all_routes) do
    all_routes
    |> Enum.group_by(&Map.take(&1, [:action, :relationship]))
    |> Enum.flat_map(fn {info, routes} ->
      case routes do
        [route] ->
          [%{route | primary?: true}]

        routes ->
          case Enum.count(routes, & &1.primary?) do
            0 ->
              # TODO: Format these prettier
              raise "Must declare a primary route for #{format_action(info)}, as there are more than one."

            1 ->
              routes

            _ ->
              raise "Duplicate primary routes declared for #{format_action(info)}, but there can only be one primary route."
          end
      end
    end)
  end

  defp format_action(%{action: action, relationship: nil}), do: "`#{action}`"

  defp format_action(%{action: action, relationship: relationship}),
    do: "`#{action}`: `#{relationship}`"
end
