defmodule AshJsonApi.Controllers.GetRelationship do
  def init(options) do
    # initialize options
    options
  end

  def call(%{path_params: %{"id" => id}} = conn, options) do
    resource = options[:resource]
    relationship = options[:relationship]
    related_resource = relationship.destination

    with {:ok, request} <-
           AshJsonApi.Request.from(conn, related_resource, :get_relationship),
         {:record, {:ok, record}} when not is_nil(record) <-
           {:record, Ash.Data.get_by_id(resource, id)},
         {:ok, record, related} <-
           AshJsonApi.Includes.Includer.get_includes(record, %{
             request
             | includes: [[relationship.name]]
           }) do
      serialized =
        case relationship do
          %{cardinality: :one} ->
            AshJsonApi.Serializer.serialize_to_one_relationship(
              request,
              record,
              relationship,
              related
            )

          %{cardinality: :many} ->
            AshJsonApi.Serializer.serialize_to_many_relationship(
              request,
              record,
              relationship,
              related
            )
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/vnd.api+json")
      |> Plug.Conn.send_resp(200, serialized)
    end
  end
end
