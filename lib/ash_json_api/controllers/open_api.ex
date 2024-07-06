if Code.ensure_loaded?(OpenApiSpex) do
  defmodule AshJsonApi.Controllers.OpenApi do
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

    @doc false
    def spec(conn, opts) do
      phoenix_endpoint = opts[:phoenix_endpoint] || conn.private[:phoenix_endpoint]

      opts
      |> Keyword.put(:phoenix_endpoint, phoenix_endpoint)
      |> AshJsonApi.OpenApi.spec(conn)
    end
  end
end
