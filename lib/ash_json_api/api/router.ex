defmodule AshJsonApi.Api.Router do
  defmacro __using__(opts) do
    quote bind_quoted: [
            api: opts[:api],
            prefix: opts[:prefix],
            resources: opts[:resources],
            serve_schema: opts[:serve_schema]
          ],
          location: :keep do
      defmodule Router do
        # And get that into phoenix
        use Plug.Router
        require Ash

        plug(:match)

        plug(Plug.Parsers,
          parsers: [:json],
          pass: ["application/vnd.api+json"],
          json_decoder: Jason
        )

        plug(:dispatch)

        # TODO: This compile time dependency here may very well cause the entire application
        # to recompile for all resources. These things may need to be retrieved from the module
        # attributes or pushed to runtime if possible.
        resources
        |> Enum.filter(&(AshJsonApi.JsonApiResource in &1.extensions()))
        |> Enum.map(fn resource ->
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
                relationship: Ash.relationship(resource, relationship_name),
                action: Ash.action(resource, action_name, action_type),
                resource: resource,
                api: api,
                prefix: prefix,
                route: route_struct
              ]
              |> Enum.reject(fn {_k, v} -> is_nil(v) end)

            match(route, via: method, to: controller, init_opts: opts)
          end
        end)

        if serve_schema do
          match("/schema",
            via: :get,
            to: AshJsonApi.Controllers.Schema,
            init_opts: [api: api]
          )
        end

        match(_, to: AshJsonApi.Controllers.NoRouteFound)
      end
    end
  end

  # TODO: This is pretty naive
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
