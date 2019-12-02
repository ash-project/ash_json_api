defmodule AshJsonApi.Controllers.Create do
  alias AshJsonApi.Controllers.Response
  alias AshJsonApi.Error

  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    resource = options[:resource]
    action = options[:action]

    request = AshJsonApi.Request.from(conn, resource, action, options[:api])

    with %{errors: []} <- request,
         {:record, {:ok, record}} when not is_nil(record) <-
           {:record,
            Ash.run_create_action(
              resource,
              action,
              request.attributes,
              request.relationships,
              request.query_params
            )},
         {:include, {:ok, record, includes}} <-
           {:include, AshJsonApi.Includes.Includer.get_includes(record, request)} do
      serialized = AshJsonApi.Serializer.serialize_one(request, record, includes)

      conn
      |> Plug.Conn.put_resp_content_type("application/vnd.api+json")
      |> Plug.Conn.send_resp(200, serialized)
    else
      %{errors: errors} ->
        Response.render_errors(conn, request, errors)

      {:record, {:error, db_error}} ->
        error =
          Error.FrameworkError.new(
            internal_description:
              "failed to create record for resource: #{inspect(resource)} | #{inspect(db_error)}"
          )

        Response.render_errors(conn, request, error)

      {:include, {:error, _error}} ->
        error = Error.FrameworkError.new(internal_description: "Failed to include")

        Response.render_errors(conn, request, error)
    end
  end
end
