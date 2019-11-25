defmodule AshJsonApi.Controllers.Get do
  alias AshJsonApi.Controllers.Response
  alias AshJsonApi.Error

  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    resource = options[:resource]
    action = options[:action]

    request = AshJsonApi.Request.from(conn, resource, action)
    request = %{request | path_params: %{}}

    with %{errors: []} <- request,
         {:id, {:ok, id}} <- {:id, Map.fetch(request.path_params, "id")},
         {:record, {:ok, record}} when not is_nil(record) <-
           {:record, Ash.get(resource, id, %{}, action)},
         {:include, {:ok, record, includes}} <-
           {:include, AshJsonApi.Includes.Includer.get_includes(record, request)} do
      Response.render_one(conn, request, 200, record, includes)
    else
      {:include, {:error, _error}} ->
        error = Error.FrameworkError.new(internal_description: "Failed to include")

        Response.render_errors(conn, request, error)

      {:id, :error} ->
        error =
          Error.FrameworkError.new(
            internal_description: "id path parameter not present in get route: #{request.url}"
          )

        Response.render_errors(conn, request, error)

      %{errors: errors} ->
        Response.render_errors(conn, request, errors)

      {:record, {:error, db_error}} ->
        id = Map.get(request.path_params, "id")

        error =
          Error.FrameworkError.new(
            internal_description:
              "failed to retrieve record by id for resource: #{inspect(resource)}, id: #{
                inspect(id)
              } | #{inspect(db_error)}"
          )

        Response.render_errors(conn, request, error)

      {:record, {:ok, nil}} ->
        id = Map.get(request.path_params, "id")
        error = Error.NotFound.new(id: id, resource: resource)

        Response.render_errors(conn, request, error)
    end
  end
end
