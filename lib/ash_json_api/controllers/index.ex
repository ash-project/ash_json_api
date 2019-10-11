defmodule AshJsonApi.Controllers.Index do
  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    resource = options[:resource]

    with {:ok, request} <- AshJsonApi.Request.from(conn, resource, :index),
         {:ok, query} <- Ash.Data.resource_to_query(resource),
         {:ok, paginator} <- AshJsonApi.Paginator.paginate(request, query),
         {:ok, found} <- Ash.Data.get_many(paginator.query, resource),
         {:ok, records, includes} <-
           AshJsonApi.Includes.Includer.get_includes(found, request) do
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
