defmodule AshJsonApi.Controllers.Index do
  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    resource = options[:resource]
    action = options[:action]

    with {:ok, request} <- AshJsonApi.Request.from(conn, resource, :index),
         {:ok, paginator} <- Ash.run_index_action(resource, action, request.query_params),
         {:ok, records, includes} <-
           AshJsonApi.Includes.Includer.get_includes(paginator.results, request) do
      serialized = AshJsonApi.Serializer.serialize_many(request, paginator, records, includes)

      conn
      |> Plug.Conn.put_resp_content_type("application/vnd.api+json")
      |> Plug.Conn.send_resp(200, serialized)
      |> Plug.Conn.halt()
    else
      {:error, error} ->
        raise "whups #{inspect(error)}"
    end
  end
end
