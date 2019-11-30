defmodule AshJsonApi.Controllers.NoRouteFound do
  def init(options) do
    # initialize options
    options
  end

  def call(conn, _options) do
    IO.inspect("No route found")

    # TODO: render this as a JSON parsable error
    conn
    |> Plug.Conn.send_resp(404, "no route found")
    |> Plug.Conn.halt()
  end
end
