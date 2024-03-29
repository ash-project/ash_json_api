defmodule AshJsonApi.Controllers.PostToRelationship do
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

    conn
    |> Request.from(resource, action, domain, route)
    |> Helpers.fetch_record_from_path(options[:resource])
    |> Helpers.add_to_relationship(relationship.name)
    |> Helpers.render_or_render_errors(conn, fn request ->
      Response.render_many_relationship(conn, request, 200, relationship)
    end)
  end
end
