defmodule AshJsonApi.Controllers.Schema do
  def init(options) do
    # initialize options
    options
  end

  def call(conn, opts) do
    # TODO: render this as a JSON parsable error
    api = opts[:api]

    schema =
      api
      |> AshJsonApi.JsonSchema.generate()
      |> Jason.encode!()

    conn
    |> Plug.Conn.send_resp(200, schema)
    |> Plug.Conn.halt()
  end
end
