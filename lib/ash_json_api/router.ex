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
              relationship: relationship_name
            } <-
              AshJsonApi.routes(resource) do
          opts =
            [
              relationship: Ash.relationship(resource, relationship_name),
              action: Ash.action(resource, action_name),
              resource: resource
            ]
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)

          IO.inspect("#{method}: #{route}")
          match(route, via: method, to: controller, init_opts: opts)
        end
      end)

      match(_, to: AshJsonApi.Controllers.NoRouteFound)
    end
  end
end
