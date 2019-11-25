defmodule AshJsonApi.Router do
  defmacro __using__(_) do
    quote do
      # TODO: Make it so that these can have their routes printed
      # And get that into phoenix
      use Plug.Router

      plug(:match)

      plug(Plug.Parsers,
        parsers: [:json],
        pass: ["application/json"],
        json_decoder: Jason
      )

      plug(:dispatch)

      Ash.resources()
      |> Enum.filter(&(AshJsonApi in &1.mix_ins()))
      |> Enum.map(fn resource ->
        for %{
              route: route,
              action: action_name,
              controller: controller,
              method: method,
              action_type: action_type,
              relationship: relationship_name,
              paginate?: paginate?
            } = route_struct <-
              AshJsonApi.Router.routes(resource) do
          opts =
            [
              relationship: Ash.relationship(resource, relationship_name),
              action: Ash.action(resource, action_name, action_type),
              resource: resource,
              paginate?: paginate?
            ]
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)

          match(route, via: method, to: controller, init_opts: opts)
        end
      end)

      match(_, to: AshJsonApi.Controllers.NoRouteFound)
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
