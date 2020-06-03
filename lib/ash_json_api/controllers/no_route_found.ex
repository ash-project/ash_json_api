defmodule AshJsonApi.Controllers.NoRouteFound do
  @moduledoc false
  def init(options) do
    # initialize options
    options
  end

  def call(conn, _options) do
    # TODO: render this as a JSON parsable error
    conn
    |> Plug.Conn.send_resp(404, "no route found")
    |> Plug.Conn.halt()
  end
end
