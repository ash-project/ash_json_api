defmodule AshJsonApi.Controllers.OpenApi do
  @moduledoc false
  def init(options) do
    options
  end

  # sobelow_skip ["XSS.SendResp"]
  def call(conn, opts) do
    {mod, _opts}= opts[:open_api]

    spec =
      mod.spec()
      |> Jason.encode!(pretty: true)

    conn
    |> Plug.Conn.send_resp(200, spec)
    |> Plug.Conn.halt()
  end
end
