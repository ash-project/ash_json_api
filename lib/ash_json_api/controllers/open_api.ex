if Code.ensure_loaded?(OpenApiSpex) do
  defmodule AshJsonApi.Controllers.OpenApi do
    @moduledoc false
    def init(options) do
      options
    end

    # sobelow_skip ["XSS.SendResp"]
    def call(conn, opts) do
      prefix =
        conn.request_path
        |> Path.split()
        |> Enum.reverse()
        |> Enum.drop(Enum.count(conn.path_info))
        |> Enum.reverse()
        |> case do
          [] -> "/"
          paths -> Path.join(paths)
        end

      spec =
        conn
        |> spec(Keyword.put(opts, :prefix, prefix))
        |> Jason.encode!(pretty: true)

      conn
      |> Plug.Conn.send_resp(200, spec)
      |> Plug.Conn.halt()
    end

    @doc false
    # sobelow_skip ["Traversal.FileModule"]
    def spec(conn, opts) do
      if path = opts[:open_api_file] do
        File.read!(path)
        |> Jason.decode!()
      else
        phoenix_endpoint = opts[:phoenix_endpoint] || conn.private[:phoenix_endpoint]

        opts
        |> Keyword.put(:phoenix_endpoint, phoenix_endpoint)
        |> AshJsonApi.OpenApi.spec(conn)
      end
    end
  end
end
