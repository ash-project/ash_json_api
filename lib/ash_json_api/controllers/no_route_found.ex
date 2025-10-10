# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.NoRouteFound do
  @moduledoc false
  def init(options) do
    # initialize options
    options
  end

  def call(conn, _options) do
    errors =
      AshJsonApi.Serializer.serialize_errors(nil, [
        %AshJsonApi.Error{
          id: Ash.UUID.generate(),
          status_code: 404,
          code: "no_route_found",
          title: "NoRouteFound",
          detail: "no route found",
          meta: %{}
        }
      ])

    conn
    |> Plug.Conn.put_resp_content_type("application/vnd.api+json")
    |> Plug.Conn.send_resp(404, errors)
    |> Plug.Conn.halt()
  end
end
