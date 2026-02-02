# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.GetRelated do
  @moduledoc false
  alias AshJsonApi.Controllers.{Helpers, Response}
  alias AshJsonApi.Request

  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    action = options[:action]
    domain = options[:domain]
    route = options[:route]
    relationship = Ash.Resource.Info.public_relationship(options[:resource], route.relationship)
    resource = relationship.destination
    all_domains = options[:all_domains]

    conn
    |> Request.from(resource, action, domain, all_domains, route, options[:prefix])
    |> Helpers.fetch_related(options[:resource])
    |> Helpers.fetch_includes()
    |> Helpers.fetch_metadata()
    |> Helpers.render_or_render_errors(conn, fn conn, request ->
      case relationship.cardinality do
        :one ->
          Response.render_one(
            conn,
            request,
            200,
            List.first(request.assigns.result),
            request.assigns.includes
          )

        :many ->
          Response.render_many(
            conn,
            request,
            200,
            request.assigns.result,
            request.assigns.includes
          )
      end
    end)
  end
end
