defmodule AshJsonApi.Controllers.Index do
  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    resource = options[:resource]
    action = options[:action]
    paginate? = options[:paginate?]

    with {:ok, request} <- AshJsonApi.Request.from(conn, resource, action),
         {:ok, params} <- params(conn.query_params, paginate?),
         {:ok, paginator} <- Ash.read(resource, params, action),
         {:ok, records, includes} <-
           AshJsonApi.Includes.Includer.get_includes(paginator.results, request) do
      IO.inspect(params)

      serialized =
        AshJsonApi.Serializer.serialize_many(
          request,
          paginator,
          records,
          includes,
          nil,
          paginate?
        )

      conn
      |> Plug.Conn.put_resp_content_type("application/vnd.api+json")
      |> Plug.Conn.send_resp(200, serialized)
      |> Plug.Conn.halt()
    else
      {:error, error} ->
        raise "whups #{inspect(error)}"
    end
  end

  def params(query_params, paginate?) do
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
         %{"limit" => limit} <- IO.inspect(page),
         {:integer, {integer, ""}} <- {:integer, Integer.parse(limit)} do
      {:ok,
       params
       |> Map.put_new(:page, %{})
       |> Map.update!(:page, &Map.put(&1, :limit, integer))}
    else
      {:integer, {_integer, _remaining}} ->
        {:error, "invalid limit parameter"}

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
        {:error, "invalid offset parameter"}

      _ ->
        {:ok, params}
    end
  end
end
