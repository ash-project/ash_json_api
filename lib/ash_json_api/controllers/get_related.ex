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
    api = options[:api]
    route = options[:route]
    relationship = Ash.Resource.relationship(options[:resource], route.relationship)
    resource = relationship.destination

    conn
    |> Request.from(resource, action, api, route)
    |> Helpers.fetch_record_from_path(options[:resource])
    |> Helpers.fetch_related()
    |> Helpers.fetch_includes()
    |> Helpers.render_or_render_errors(conn, fn request ->
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
            request.assigns.includes,
            false
          )
      end
    end)
  end
end
