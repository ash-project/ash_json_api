# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.Delete do
  @moduledoc false
  alias AshJsonApi.Controllers.{Helpers, Response}
  alias AshJsonApi.Request

  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    resource = options[:resource]
    action = options[:action]
    domain = options[:domain]
    route = options[:route]
    all_domains = options[:all_domains]

    conn
    |> Request.from(resource, action, domain, all_domains, route, options[:prefix])
    |> then(fn request ->
      cond do
        request.action.type != :update ->
          Helpers.destroy_record(request)

        body_present?(conn) ->
          error =
            AshJsonApi.Error.new(
              status_code: 400,
              code: "invalid_body",
              title: "InvalidBody",
              detail:
                "DELETE requests that run update actions must not include a body. " <>
                  "Support for request bodies is deferred to a future change."
            )

          Request.add_error(request, error, :delete)

        true ->
          Helpers.update_record(request)
      end
    end)
    |> Helpers.fetch_includes()
    |> Helpers.fetch_metadata()
    |> Helpers.render_or_render_errors(conn, fn conn, request ->
      Response.render_one(conn, request, 200, request.assigns.result, request.assigns.includes)
    end)
  end

  defp body_present?(conn) do
    Map.get_lazy(conn.private, :ash_json_api_delete_body?, fn ->
      conn.body_params != %{} or
        Enum.any?(Plug.Conn.get_req_header(conn, "content-length"), fn length ->
          case Integer.parse(length) do
            {bytes, ""} -> bytes > 0
            _ -> false
          end
        end)
    end)
  end
end
