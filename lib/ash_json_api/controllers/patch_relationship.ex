defmodule AshJsonApi.Controllers.PatchRelationship do
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
    resource = options[:resource]
    relationship = Ash.relationship(options[:resource], route.relationship)

    conn
    |> Request.from(resource, action, api, route)
    |> Helpers.fetch_record_from_path(options[:resource])
    |> Helpers.replace_relationship(relationship.name)
    |> Helpers.render_or_render_errors(conn, fn request ->
      Response.render_many_relationship(conn, request, 200, relationship)
    end)
  end
end
