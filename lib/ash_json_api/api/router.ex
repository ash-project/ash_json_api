defmodule AshJsonApi.Api.Router do
  @moduledoc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      api = opts[:api] || raise "Api option must be provided"
      registry = opts[:registry] || raise "registry option must be provided"
      prefix = AshJsonApi.Api.Info.prefix(api)
      serve_schema? = AshJsonApi.Api.Info.serve_schema?(api)
      resources = Ash.Registry.Info.entries(registry)

      use Plug.Router
      require Ash

      plug(:match)

      plug(Plug.Parsers,
        parsers: [:json],
        pass: ["application/vnd.api+json"],
        json_decoder: Jason
      )

      plug(:dispatch)

      resources
      |> Enum.filter(&(AshJsonApi.Resource in Spark.extensions(&1)))
      |> Enum.each(fn resource ->
        for %{
              route: route,
              action: action_name,
              controller: controller,
              method: method,
              relationship: relationship_name
            } = route_struct <-
              AshJsonApi.Api.Router.routes(resource) do
          opts =
            [
              relationship: Ash.Resource.Info.public_relationship(resource, relationship_name),
              action: Ash.Resource.Info.action(resource, action_name),
              resource: resource,
              api: api,
              prefix: prefix,
              route: route_struct
            ]
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)

          match(route, via: method, to: controller, init_opts: opts)
        end
      end)

      if serve_schema? do
        match("/schema",
          via: :get,
          to: AshJsonApi.Controllers.Schema,
          init_opts: [api: api]
        )

        match("/schema.json",
          via: :get,
          to: AshJsonApi.Controllers.Schema,
          init_opts: [api: api]
        )
      end

      match(_, to: AshJsonApi.Controllers.NoRouteFound)
    end
  end

  @doc false
  def routes(resource) do
    resource
    |> AshJsonApi.Resource.Info.routes()
    |> Enum.sort(fn left, right ->
      left_path = Path.split(left.route)
      right_path = Path.split(right.route)

      left_path
      |> Enum.zip(right_path)
      |> sorts_first?()
      |> case do
        :undecided ->
          Enum.count(left_path) > Enum.count(right_path)

        result ->
          result
      end
    end)
  end

  defp sorts_first?(zipped) do
    Enum.reduce_while(zipped, :undecided, fn {left_part, right_part}, :undecided ->
      left_param? = String.starts_with?(left_part, ":")
      right_param? = String.starts_with?(right_part, ":")

      cond do
        left_part == right_part ->
          {:cont, :undecided}

        left_param? and not right_param? ->
          {:halt, false}

        not left_param? and right_param? ->
          {:halt, true}

        true ->
          {:cont, :undecided}
      end
    end)
  end
end
