# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.BulkUpdate do
  @moduledoc false
  alias AshJsonApi.Controllers.{Helpers, Response}
  alias AshJsonApi.Request

  def init(options) do
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
    |> Helpers.bulk_update_records()
    |> Helpers.fetch_includes()
    |> Helpers.fetch_metadata()
    |> Helpers.render_or_render_errors(conn, fn conn, request ->
      case request.assigns.bulk_status do
        :success ->
          Response.render_many(
            conn,
            request,
            route.success_status || 200,
            request.assigns.result,
            request.assigns.includes
          )

        _ ->
          Response.render_bulk_update(conn, request, request.assigns.includes)
      end
    end)
  end
end
