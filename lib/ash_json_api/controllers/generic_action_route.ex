# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.GenericActionRoute do
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
    |> Helpers.run_action()
    |> Helpers.render_or_render_errors(conn, fn conn, request ->
      status =
        case route.method do
          :post -> 201
          _ -> 200
        end

      Response.render_generic_action_result(
        conn,
        request,
        status,
        request.assigns.result,
        action.returns
      )
    end)
  end
end
