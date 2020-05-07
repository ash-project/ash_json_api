defmodule AshJsonApi.Controllers.GetRelated do
  alias AshJsonApi.Controllers.{Helpers, Response}
  alias AshJsonApi.Request

  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    action = options[:action]
    api = options[:api]
    route = options[:route]
    resource = Ash.relationship(options[:resource], route.relationship).destination

    conn
    |> Request.from(resource, action, api, route)
    |> Helpers.fetch_record_from_path(options[:resource])
    |> Helpers.fetch_related()
    |> Helpers.fetch_includes()
    |> Helpers.render_or_render_errors(conn, fn request ->
      Response.render_one(conn, request, 201, request.assigns.result, request.assigns.includes)
    end)
  end
end
