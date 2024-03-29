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

    conn
    |> Request.from(resource, action, domain, route)
    |> Helpers.fetch_record_from_path()
    |> Helpers.destroy_record()
    |> Helpers.fetch_includes()
    |> Helpers.render_or_render_errors(conn, fn request ->
      Response.render_one(conn, request, 200, request.assigns.result, request.assigns.includes)
    end)
  end
end
