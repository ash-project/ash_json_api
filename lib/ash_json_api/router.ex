defmodule AshJsonApi.Router do
  @moduledoc """
  Use this module to create a router for your AshJsonApi.

  To use this, create a module and do the following:

  ```elixir
  defmodule YourRouter do
    use AshJsonApi.Router,
      domains: [YourDomain, YourOtherDomain],
      # these next two are optional, only add them if you want those endpoints
      open_api: "/open_api",
      json_schema: "/json_schema",
      # tell us where it is mounted in your router
      prefix: "/api/json"
  end
  ```

  Then in your Phoenix router or plug pipeline, forward to this plug.
  In phoenix, that looks like this:

  ```elixir
      forward "/api", YourRouter
  ```

  ## Customizing request handling

  You can provide the `before_dispatch` option to customize request handling.
  This can also be used to do things like set monitoring/observability information,
  like which domain/resource/route is handling the request.

  For example:

  ```elixir
  use AshJsonApi.Router,
    ...,
    before_dispatch: {__MODULE__, :before_dispatch, []}


  def before_dispatch(conn, route_info) do
   ...
  end
  ```

  `route_info` will be one of the following:

  - `:open_api` - The open api is being requested
  - `:json_schema` - The json schema is being requested
  - `:not_found` - No matching route was found
  - A map containing the keys: `domain`, `resource`, `route`, `params`
  """
  defmacro __using__(opts) do
    opts = Macro.expand_literals(opts, __CALLER__)

    quote bind_quoted: [opts: opts] do
      require Ash.Domain.Info
      use Plug.Router
      require Ash
      @opts opts
      @domains List.wrap(@opts[:domain] || @opts[:domains])
      @opts Keyword.put(@opts, :domains, @domains)

      if Code.ensure_loaded?(Phoenix.Router) &&
           function_exported?(Phoenix.Router, :__formatted_routes__, 1) do
        @behaviour Phoenix.VerifiedRoutes

        def formatted_routes(_opts) do
          AshJsonApi.Router.formatted_routes(__MODULE__)
        end

        def verified_route?(_opts, path) do
          AshJsonApi.Router.verified_route?(__MODULE__, path)
        end
      end

      def domains do
        @domains
      end

      plug(:match)

      plug(Plug.Parsers,
        parsers: [:json],
        pass: ["application/vnd.api+json"],
        json_decoder: Jason
      )

      plug(:dispatch)

      match(_,
        to: AshJsonApi.Controllers.Router,
        init_opts: @opts
      )

      if Code.ensure_loaded?(AshJsonApi.OpenApi) do
        def spec do
          AshJsonApi.OpenApi.spec(@opts)
        end
      end
    end
  end

  @doc false
  def formatted_routes(router) do
    router.domains()
    |> Enum.flat_map(&AshJsonApi.Domain.Info.routes/1)
    |> Enum.map(fn route ->
      plug_opts = [resource: route.resource, action: route.action]

      %{
        verb: route.method,
        path: route.route,
        label: "#{inspect(router)} #{inspect(plug_opts)}",
        plug_opts: plug_opts
      }
    end)
  end

  @doc false
  def verified_route?(router, path) do
    router
    |> formatted_routes()
    |> Enum.map(fn route ->
      case Path.split(route.path) do
        ["/" | rest] -> rest
        path -> path
      end
    end)
    |> Enum.any?(&match_path?(&1, path))
  end

  defp match_path?([], []), do: true
  defp match_path?([], _), do: false
  defp match_path?(_, []), do: false

  defp match_path?([":" <> _ | rest_route], [_ | rest_path]) do
    match_path?(rest_route, rest_path)
  end

  defp match_path?(["_" <> _ | rest_route], [_ | rest_path]) do
    match_path?(rest_route, rest_path)
  end

  defp match_path?(["*" <> _], _) do
    true
  end

  defp match_path?([same | rest_path], [same | rest_route]) do
    match_path?(rest_path, rest_route)
  end

  defp match_path?(_, _) do
    false
  end
end
