defmodule AshJsonApi.Controllers.Response do
  require Logger

  def render_errors(conn, request, opts \\ []) do
    errors =
      request.errors
      |> List.flatten()
      |> Enum.map(fn error ->
        if is_bitstring(error) do
          AshJsonApi.Error.FrameworkError.new(internal_description: error)
        else
          error
        end
      end)

    unless opts[:log?] == false do
      Enum.each(errors, fn error ->
        if is_bitstring(error) do
          Logger.error(
            AshJsonApi.Error.format_log(error),
            opts[:logger_metadata] || []
          )
        else
          Logger.log(
            error.log_level,
            fn -> AshJsonApi.Error.format_log(error) end,
            opts[:logger_metadata] || []
          )
        end
      end)
    end

    status = opts[:status_code] || error_status_code(errors)
    serialized = AshJsonApi.Serializer.serialize_errors(request, errors)

    send_resp(conn, status, serialized)
  end

  def render_one(conn, request, status, record, includes) do
    serialized = AshJsonApi.Serializer.serialize_one(request, record, includes)

    send_resp(conn, status, serialized)
  end

  def render_many(
        conn,
        request,
        status,
        paginator,
        includes,
        paginate? \\ true,
        top_level_meta \\ nil
      ) do
    serialized =
      AshJsonApi.Serializer.serialize_many(
        request,
        paginator,
        includes,
        paginate?,
        top_level_meta
      )

    send_resp(conn, status, serialized)
  end

  def render_one_relationship(conn, request, status, relationship) do
    serialized =
      AshJsonApi.Serializer.serialize_to_one_relationship(
        request,
        request.assigns.record_from_path,
        relationship,
        request.assigns.result
      )

    send_resp(conn, status, serialized)
  end

  def render_many_relationship(conn, status, request, relationship) do
    serialized =
      AshJsonApi.Serializer.serialize_to_many_relationship(
        request,
        request.assigns.record_from_path,
        relationship,
        request.assigns.result
      )

    send_resp(conn, status, serialized)
  end

  defp send_resp(conn, status, serialized) do
    conn
    |> Plug.Conn.put_resp_content_type("application/vnd.api+json", nil)
    |> Plug.Conn.send_resp(status, serialized)
  end

  defp error_status_code(errors) do
    errors
    |> Stream.map(&Map.get(&1, :status_code))
    |> Enum.reject(&(&1 == :undefined))
    |> Enum.max(fn -> 500 end)
  end
end
