# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.Response do
  @moduledoc false
  require Logger

  @generic_action_no_return_success Jason.encode!(%{success: true})

  # sobelow_skip ["XSS.SendResp"]
  def render_errors(conn, request, opts \\ []) do
    if AshJsonApi.Domain.Info.log_errors?(request.domain) do
      log_errors(request.errors, opts)
    end

    status = opts[:status_code] || error_status_code(request.errors)
    serialized = AshJsonApi.Serializer.serialize_errors(request, request.errors)

    send_resp(conn, status, serialized)
  end

  # sobelow_skip ["XSS.SendResp"]
  def render_generic_action_result(conn, request, status, result, returns) do
    if returns do
      result
      |> AshJsonApi.Serializer.serialize_value(
        request.action.returns,
        request.action.constraints,
        request.domain
      )
      |> then(fn serialized ->
        if request.route.wrap_in_result? do
          send_resp(conn, status, Jason.encode!(%{result: serialized}))
        else
          send_resp(conn, status, Jason.encode!(serialized))
        end
      end)
    else
      send_resp(conn, status, @generic_action_no_return_success)
    end
  end

  defp log_errors(errors, opts) do
    Enum.each(errors, fn error ->
      if is_bitstring(error) do
        Logger.error(
          AshJsonApi.Error.format_log(error),
          opts[:logger_metadata] || []
        )
      else
        case error do
          %AshJsonApi.Error{} ->
            Logger.log(
              error.log_level,
              fn -> AshJsonApi.Error.format_log(error) end,
              opts[:logger_metadata] || []
            )

          other ->
            Logger.log(:error, fn ->
              case other do
                %{stacktrace: %{stacktrace: stacktrace}} ->
                  Exception.format(:error, other, stacktrace)

                _ ->
                  Exception.format(:error, other)
              end
            end)
        end
      end
    end)
  end

  # sobelow_skip ["XSS.SendResp"]
  def render_one(conn, request, status, record, includes) do
    meta = Map.get(request.assigns, :metadata, %{})

    serialized = AshJsonApi.Serializer.serialize_one(request, record, includes, meta)

    send_resp(conn, status, serialized)
  end

  # sobelow_skip ["XSS.SendResp"]
  def render_many(
        conn,
        request,
        status,
        paginator,
        includes
      ) do
    meta = Map.get(request.assigns, :metadata, %{})

    serialized =
      AshJsonApi.Serializer.serialize_many(
        request,
        paginator,
        includes,
        meta
      )

    send_resp(conn, status, serialized)
  end

  # sobelow_skip ["XSS.SendResp"]
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

  # sobelow_skip ["XSS.SendResp"]
  def render_many_relationship(conn, request, status, relationship) do
    serialized =
      AshJsonApi.Serializer.serialize_to_many_relationship(
        request,
        request.assigns.record_from_path,
        relationship,
        request.assigns.result,
        request.assigns.metadata
      )

    send_resp(conn, status, serialized)
  end

  defp send_resp(conn, status, serialized) do
    conn
    |> Plug.Conn.put_resp_content_type("application/vnd.api+json", nil)
    |> put_new_status(status)
    |> Map.put(:resp_body, serialized)
    |> Map.put(:state, :set)
    |> Plug.Conn.send_resp()
  end

  def put_new_status(%{status: nil} = conn, status) do
    Plug.Conn.put_status(conn, status)
  end

  def put_new_status(conn, _status), do: conn

  defp error_status_code(errors) do
    errors
    |> Stream.filter(&is_map/1)
    |> Stream.map(&Map.get(&1, :status_code))
    |> Enum.reject(&(&1 == :undefined))
    |> Enum.max(fn -> 500 end)
  end
end
