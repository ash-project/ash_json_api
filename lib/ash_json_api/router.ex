defmodule AshJsonApi.Router do
  defmacro __using__(_) do
    quote do
      # TODO: Make it so that these can have their routes printed
      # And get that into phoenix
      use Plug.Router
      require AshJsonApi.RouteBuilder

      plug(:match)

      plug(Plug.Parsers,
        parsers: [:json],
        pass: ["application/json"],
        json_decoder: Jason
      )

      plug(:dispatch)

      for resource <- Ash.resources() do
        Code.ensure_compiled(resource)

        AshJsonApi.RouteBuilder.build_resource_routes(resource)
      end

      match(_, to: AshJsonApi.Controllers.NoRouteFound)
    end
  end
end
