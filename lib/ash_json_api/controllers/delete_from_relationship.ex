defmodule AshJsonApi.Controllers.DeleteFromRelationship do
  def init(options) do
    # initialize options
    options
  end

  def call(%{path_params: %{"id" => id}} = conn, options) do
    resource = options[:resource]
    relationship = options[:relationship]
    related_resource = relationship.destination

    with {:ok, request} <-
           AshJsonApi.Request.from(conn, related_resource, :delete_from_relationship),
         %{cardinality: :many} <- relationship,
         {:record, {:ok, record}} when not is_nil(record) <-
           {:record, Ash.Data.get_by_id(resource, id)},
         {:updated, {:ok, updated}} <-
           {:updated, Ash.Data.delete_related(record, relationship, request.resource_identifiers)},
         {:ok, record, related} <-
           AshJsonApi.Includes.Includer.get_includes(updated, %{
             request
             | includes: [[relationship.name]]
           }) do
      serialized =
        AshJsonApi.Serializer.serialize_to_many_relationship(
          request,
          record,
          relationship,
          related
        )

      conn
      |> Plug.Conn.put_resp_content_type("application/vnd.api+json")
      |> Plug.Conn.send_resp(200, serialized)
    else
      %{cardinality: :one} ->
        raise "can only delete from a to_many relationship"

      _ ->
        raise "uh oh"
    end
  end
end
