defmodule AshJsonApi.Controllers.Index do
  alias AshJsonApi.Controllers.Response
  alias AshJsonApi.Error

  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    resource = options[:resource]
    action = options[:action]
    paginate? = options[:paginate?]

    request = AshJsonApi.Request.from(conn, resource, action)

    with %{errors: []} <- request,
         {:params, {:ok, params}} <- {:params, params(conn.query_params, paginate?)},
         {:read, {:ok, paginator}} <- {:read, Ash.read(resource, params, action)},
         {:include, {:ok, records, includes}} <-
           {:include, AshJsonApi.Includes.Includer.get_includes(paginator.results, request)} do
      Response.render_many(conn, request, paginator, records, includes, paginate?)
    else
      {:include, {:error, _error}} ->
        error = Error.FrameworkError.new(internal_description: "Failed to include")

        Response.render_errors(conn, request, error)

      {:read, {:error, _error}} ->
        error =
          Error.FrameworkError.new(
            internal_description: "Failed to read resource #{inspect(resource)}"
          )

        Response.render_errors(conn, request, error)

      %{errors: errors} ->
        Response.render_errors(conn, request, errors)

      {:params, {:error, error}} ->
        Response.render_errors(conn, request, error)
    end
  end

  defp params(query_params, paginate?) do
    with {:ok, params} <- add_limit(%{}, query_params),
         {:ok, params} <- add_offset(params, params) do
      {:ok, Map.put(params, :paginate?, paginate?)}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp add_limit(params, query_params) do
    with %{"page" => page} <- query_params,
         %{"limit" => limit} <- page,
         {:integer, {integer, ""}} <- {:integer, Integer.parse(limit)} do
      {:ok,
       params
       |> Map.put_new(:page, %{})
       |> Map.update!(:page, &Map.put(&1, :limit, integer))}
    else
      {:integer, {_integer, _remaining}} ->
        {:error, Error.InvalidPagination.new(parameter: "page[limit]")}

      _ ->
        {:ok, params}
    end
  end

  defp add_offset(params, query_params) do
    with %{"page" => page} <- query_params,
         %{"offset" => offset} <- page,
         {:integer, {integer, ""}} <- {:integer, Integer.parse(offset)} do
      {:ok,
       params
       |> Map.put_new(:page, %{})
       |> Map.update!(:page, &Map.put(&1, :offset, integer))}
    else
      {:integer, {_integer, _remaining}} ->
        {:error, Error.InvalidPagination.new(parameter: "page[offset]")}

      _ ->
        {:ok, params}
    end
  end
end
