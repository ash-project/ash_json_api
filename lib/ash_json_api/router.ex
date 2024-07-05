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
      json_schema: "/json_schema"
  end
  ```

  Then in your Phoenix router or plug pipeline, forward to this plug.
  In phoenix, that looks like this:

  ```elixir
      forward "/api", YourRouter
  ```
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: Spark.Dsl.Extension.expand_alias_no_require(opts, __CALLER__)] do
      require Ash.Domain.Info
      use Plug.Router
      require Ash
      domains = List.wrap(opts[:domain] || opts[:domains])

      plug(:match)

      plug(Plug.Parsers,
        parsers: [:json],
        pass: ["application/vnd.api+json"],
        json_decoder: Jason
      )

      plug(:dispatch)

      if domains == [] do
        raise "At least one domain option must be provided"
      end

      match(_, to: AshJsonApi.Controllers.Router, init_opts: Keyword.put(opts, :domains, domains))

      if Code.ensure_loaded?(OpenApiSpex) do
        def spec do
          AshJsonApi.OpenApi.spec(unquote(opts))
        end
      end
    end
  end
end
