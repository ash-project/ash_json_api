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

        conn.body_params != %{} ->
          error =
            AshJsonApi.Error.new(
              status_code: 400,
              code: "invalid_body",
              title: "InvalidBody",
              detail:
                "DELETE requests that run update actions accept no body or an empty JSON object."
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
end
