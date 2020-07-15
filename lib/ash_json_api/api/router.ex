defmodule AshJsonApi.Api.Router do
  @moduledoc false
  def define_router(api, resources, prefix, serve_schema?) do
    module_name = Module.concat(api, Router)

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
        |> Enum.map(fn resource ->
          Code.ensure_loaded(resource)

          resource
        end)
        |> Enum.filter(&(AshJsonApi.Resource in Ash.extensions(&1)))
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
                relationship: Ash.Resource.relationship(resource, relationship_name),
                action: Ash.Resource.action(resource, action_name, action_type),
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
    |> AshJsonApi.routes()
    |> Enum.sort_by(fn route ->
      route.route
      |> String.graphemes()
      |> Enum.count(&(&1 == ":"))
    end)
  end
end
