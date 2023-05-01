if Code.ensure_loaded?(OpenApiSpex) do
  defmodule AshJsonApi.Controllers.OpenApi do
    alias OpenApiSpex.{Info, OpenApi, SecurityScheme, Server}

    @moduledoc false
    def init(options) do
      options
    end

    # sobelow_skip ["XSS.SendResp"]
    def call(conn, opts) do
      spec =
        conn
        |> spec(opts)
        |> Jason.encode!(pretty: true)

      conn
      |> Plug.Conn.send_resp(200, spec)
      |> Plug.Conn.halt()
    end

    defp modify(spec, conn, opts) do
      case opts[:modify] do
        modify when is_function(modify) ->
          modify.(spec, conn, opts)

        {m, f, a} ->
          apply(m, f, [spec, conn, opts | a])

        _ ->
          spec
      end
    end

    @doc false
    def spec(conn, opts) do
      apis = List.wrap(opts[:api] || opts[:apis])

      servers =
        if conn.private[:phoenix_endpoint] do
          [
            Server.from_endpoint(conn.private.phoenix_endpoint)
          ]
        else
          []
        end

      %OpenApi{
        info: %Info{
          title: "Open API Specification",
          version: "1.1"
        },
        servers: servers,
        paths: AshJsonApi.OpenApi.paths(apis),
        tags: AshJsonApi.OpenApi.tags(apis),
        components: %{
          responses: AshJsonApi.OpenApi.responses(),
          schemas: AshJsonApi.OpenApi.schemas(apis),
          securitySchemes: %{
            "api_key" => %SecurityScheme{
              type: "apiKey",
              description: "API Key provided in the Authorization header",
              name: "api_key",
              in: "header"
            }
          }
        },
        security: [
          %{
            # API Key security applies to all operations
            "api_key" => []
          }
        ]
      }
      |> modify(conn, opts)
    end
  end
end
