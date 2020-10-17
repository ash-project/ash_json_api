defmodule AshJsonApi.Controllers.GetRelationship do
  @moduledoc false
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
    relationship = Ash.Resource.relationship(options[:resource], route.relationship)
    resource = relationship.destination

    conn
    |> Request.from(resource, action, api, route)
    |> Helpers.fetch_record_from_path(options[:resource])
    |> Helpers.fetch_related()
    |> Helpers.render_or_render_errors(conn, fn request ->
      case relationship do
        %{cardinality: :one} ->
          Response.render_one_relationship(conn, request, 200, relationship)

        %{cardinality: :many} ->
          Response.render_many_relationship(conn, request, 200, relationship)
      end
    end)
  end
end
