defmodule AshJsonApi.Request do
  require Logger

  alias AshJsonApi.Includes

  defstruct [
    :action,
    :resource,
    :path_params,
    :query_params,
    :includes,
    :attributes,
    :relationships,
    :resource_identifiers,
    :body,
    :url,
    :json_api_prefix
  ]

  @type t() :: %__MODULE__{}

  @type error :: {:error, AshJsonApi.Error.InvalidInclude.t()}

  @spec from(conn :: Plug.Conn.t(), resource :: Ash.Resource.t(), action :: atom) ::
          {:ok, t()} | {:error, error}
  def from(conn, resource, action) do
    with %Includes.Parser{allowed: allowed, disallowed: []} <-
           Includes.Parser.parse_and_validate_includes(resource, conn.query_params) do
      request = %__MODULE__{
        resource: resource,
        action: action,
        includes: allowed,
        url: Plug.Conn.request_url(conn),
        path_params: conn.path_params,
        query_params: conn.query_params,
        body: conn.body_params,
        attributes: parse_attributes(resource, conn),
        relationships: parse_relationships(resource, conn),
        resource_identifiers: parse_resource_identifiers(resource, conn),
        json_api_prefix: Application.get_env(:ash, :json_api_prefix) || ""
      }

      Logger.info("Got request: #{inspect(request)}")

      {:ok, request}
    else
      %Includes.Parser{disallowed: disallowed} ->
        {:error, {:invalid_includes, disallowed}}
    end
  end

  defp parse_attributes(resource, %{body_params: %{"data" => %{"attributes" => attributes}}})
       when is_map(attributes) do
    resource
    |> Ash.attributes()
    |> Enum.reduce(%{}, fn attr, acc ->
      case Map.fetch(attributes, to_string(attr.name)) do
        {:ok, value} ->
          Map.put(acc, attr.name, value)

        _ ->
          acc
      end
    end)
  end

  defp parse_attributes(_, _), do: %{}

  defp parse_relationships(resource, %{
         body_params: %{"data" => %{"relationships" => relationships}}
       })
       when is_map(relationships) do
    resource
    |> Ash.relationships()
    |> Enum.reduce(%{}, fn rel, acc ->
      param_name = to_string(rel.name)

      case relationships do
        %{^param_name => %{"data" => value}} ->
          Map.put(acc, rel.name, relationship_change_value(value))

        _ ->
          acc
      end
    end)
  end

  defp parse_relationships(_, _), do: %{}

  defp parse_resource_identifiers(_resource, %{body_params: %{"data" => data}}) when is_list(data) do
    for %{"id" => id, "type" => _type} = identifier <- data do
      case Map.fetch(identifier, "meta") do
        {:ok, meta} -> Map.put(meta, :id, id)
        _ -> %{id: id}
      end
    end
  end

  defp parse_resource_identifiers(_resource, %{body_params: %{"data" => data}}) when is_nil(data) do
    nil
  end

  defp parse_resource_identifiers(_resource, %{body_params: %{"data" => %{"id" => id, "type" => _type}}}) do
    %{id: id}
  end

  defp parse_resource_identifiers(_, _) do
    nil
  end

  defp relationship_change_value(value) when is_list(value) do
    value
    |> Stream.map(&relationship_change_value/1)
    |> Enum.reject(&is_nil/1)
  end

  defp relationship_change_value(%{"id" => id, "type" => _type} = value) do
    case Map.fetch(value, "meta") do
      {:ok, meta} -> Map.put(meta, :id, id)
      _ -> %{id: id}
    end
  end

  defp relationship_change_value(_), do: nil
end
