# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.Index do
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

    if action.type == :read do
      conn
      |> Request.from(resource, action, domain, all_domains, route, options[:prefix])
      |> Helpers.fetch_pagination_parameters()
      |> Helpers.fetch_records()
      |> Helpers.fetch_includes()
      |> Helpers.fetch_metadata()
      |> Helpers.render_or_render_errors(conn, fn conn, request ->
        Response.render_many(
          conn,
          request,
          200,
          request.assigns.result,
          request.assigns.includes
        )
      end)
    else
      conn
      |> Request.from(resource, action, domain, all_domains, route, options[:prefix])
      |> Helpers.fetch_records()
      |> Helpers.fetch_includes()
      |> Helpers.fetch_metadata()
      |> Helpers.render_or_render_errors(conn, fn conn, request ->
        Response.render_many(
          conn,
          request,
          200,
          request.assigns.result,
          request.assigns.includes
        )
      end)
    end
  end
end
