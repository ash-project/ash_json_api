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
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Ash.Domain.Info
      use Plug.Router
      require Ash
      @opts opts
      domains = List.wrap(@opts[:domain] || @opts[:domains])
      @opts Keyword.put(@opts, :domains, domains)

      def domains do
        @opts[:domains]
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
end
