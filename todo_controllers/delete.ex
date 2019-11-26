defmodule AshJsonApi.Controllers.Delete do
  def init(options) do
    # initialize options
    options
  end

  def call(%{path_params: %{"id" => id}} = conn, options) do
    resource = options[:resource]
    action = options[:action]

    with {:ok, request} <- AshJsonApi.Request.from(conn, resource, :create),
         {:record, {:ok, record}} when not is_nil(record) <-
           {:record, Ash.Data.get_by_id(resource, id)},
         {:deleted_record, {:ok, _record}} <-
           {:deleted_record, Ash.run_delete_action(record, action, request.query_params)} do
      Plug.Conn.send_resp(conn, 204, "")
    else
      {:id, :error} ->
        raise "whups, no id"

      {:error, error} ->
        raise "whups: #{inspect(error)}"

      {:updated_record, {:error, error}} ->
        raise "whups: #{inspect(error)}"

      {:record, {:error, error}} ->
        raise "whups: #{inspect(error)}"

      {:record, {:ok, nil}} ->
        conn
        # |> put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(404, "uh oh")
    end
    |> Plug.Conn.halt()
  end
end
