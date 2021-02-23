defmodule AshJsonApi.Api.Router do
  @moduledoc false
  def define_router(module_name, api, resources, prefix, serve_schema?) do
    Module.create(
      module_name,
      quote bind_quoted: [
              api: api,
              prefix: prefix,
              resources: resources,
              serve_schema?: serve_schema?
            ] do
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
        |> Enum.filter(&(AshJsonApi.Resource in Ash.Resource.Info.extensions(&1)))
        |> Enum.each(fn resource ->
          for %{
                route: route,
                action: action_name,
                controller: controller,
                method: method,
                action_type: action_type,
                relationship: relationship_name
              } = route_struct <-
                AshJsonApi.Api.Router.routes(resource) do
            opts =
              [
                relationship: Ash.Resource.Info.relationship(resource, relationship_name),
                action: Ash.Resource.Info.action(resource, action_name, action_type),
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
        end

        match(_, to: AshJsonApi.Controllers.NoRouteFound)
      end,
      Macro.Env.location(__ENV__)
    )

    module_name
  end

  @doc false
  def routes(resource) do
    resource
    |> AshJsonApi.Resource.routes()
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
