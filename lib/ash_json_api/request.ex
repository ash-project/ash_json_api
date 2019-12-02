defmodule AshJsonApi.Request do
  require Logger

  alias AshJsonApi.Includes

  defstruct [
    :api,
    :action,
    :resource,
    :path_params,
    :query_params,
    :includes,
    :includes_keyword,
    :attributes,
    :sort,
    :filter,
    :relationships,
    :resource_identifiers,
    :body,
    :url,
    :json_api_prefix,
    :user,
    errors: [],
    # assigns is used by controllers to store state while piping
    # the request around
    assigns: %{}
  ]

  @type t() :: %__MODULE__{}

  @type error :: {:error, AshJsonApi.Error.InvalidInclude.t()}

  @spec from(conn :: Plug.Conn.t(), resource :: Ash.Resource.t(), action :: atom, Keyword.t()) ::
          t
  def from(conn, resource, action, api) do
    includes = Includes.Parser.parse_and_validate_includes(resource, conn.query_params)

    %__MODULE__{
      api: api,
      resource: resource,
      action: action,
      includes: includes.allowed,
      url: Plug.Conn.request_url(conn),
      path_params: conn.path_params,
      query_params: conn.query_params,
      user: Map.get(conn.assigns, :user),
      body: conn.body_params,
      # TODO: no global config
      json_api_prefix: AshJsonApi.prefix(api)
    }
    |> parse_includes()
    |> parse_filter()
    |> parse_sort()
    |> parse_attributes()
    |> parse_relationships()
    |> parse_resource_identifiers()
  end

  def assign(request, key, value) do
    %{request | assigns: Map.put(request.assigns, key, value)}
  end

  def update_assign(request, key, default, function) do
    %{request | assigns: Map.update(request.assigns, key, default, function)}
  end

  def add_error(request, error_or_errors) do
    error_or_errors
    |> List.wrap()
    |> Enum.reduce(request, fn error, request ->
      %{request | errors: [error | request.errors]}
    end)
  end

  defp parse_filter(%{resource: resource, query_params: %{"filter" => filter}} = request)
       when is_map(filter) do
    # The validation here is not enough probably
    # Also, this logic gunna get cray
    Enum.reduce(filter, request, fn {key, value}, request ->
      cond do
        attr = Ash.attribute(resource, key) ->
          %{request | filter: Map.put(request.filter || %{}, attr.name, value)}

        rel = Ash.relationship(resource, key) ->
          %{request | filter: Map.put(request.filter || %{}, rel.name, value)}

        true ->
          add_error(request, "invalid sort: #{key}")
      end
    end)
  end

  defp parse_filter(%{query_params: %{"filter" => _}} = request) do
    add_error(request, "invalid filter")
  end

  defp parse_filter(request), do: %{request | filter: %{}}

  defp parse_sort(%{query_params: %{"sort" => sort_string}, resource: resource} = request)
       when is_bitstring(sort_string) do
    sort_string
    |> String.split(",")
    |> Enum.reduce(request, fn field, request ->
      with {order, field_name} <- trim_sort_order(field),
           {:attr, attr} when not is_nil(attr) <- {:attr, Ash.attribute(resource, field_name)} do
        %{request | sort: request.sort || [] ++ [{order, attr.name}]}
      else
        _ ->
          add_error(request, "invalid sort #{field}")
      end
    end)
  end

  defp parse_sort(%{query_params: %{"sort" => _sort_string}} = request) do
    add_error(request, "invalid sort string")
  end

  defp parse_sort(request), do: %{request | sort: []}

  defp trim_sort_order("-" <> field_name) do
    {:desc, field_name}
  end

  defp trim_sort_order(field_name) do
    {:asc, field_name}
  end

  defp parse_includes(%{resource: resource, query_params: query_params} = request) do
    includes = Includes.Parser.parse_and_validate_includes(resource, query_params)

    case includes do
      %{allowed: allowed, disallowed: []} ->
        %{request | includes: includes, includes_keyword: includes_to_keyword(allowed)}

      %{allowed: _allowed, disallowed: _disallowed} ->
        add_error(request, "invalid includes")
    end
  end

  defp includes_to_keyword(includes) do
    Enum.reduce(includes, [], fn path, acc ->
      put_path(acc, path)
    end)
  end

  defp put_path(keyword, [key]) do
    atom_key = atomize(key)
    Keyword.put_new(keyword, atom_key, [])
  end

  defp put_path(keyword, [key | rest]) do
    atom_key = atomize(key)

    keyword
    |> Keyword.put_new(atom_key, [])
    |> Keyword.update!(atom_key, &put_path(&1, rest))
  end

  defp atomize(atom) when is_atom(atom), do: atom

  defp atomize(string) when is_bitstring(string) do
    String.to_existing_atom(string)
  end

  defp parse_attributes(
         %{resource: resource, body: %{"data" => %{"attributes" => attributes}}} = request
       )
       when is_map(attributes) do
    Enum.reduce(attributes, request, fn {key, value}, request ->
      case Ash.attribute(resource, key) do
        nil ->
          add_error(request, "unknown attribute: #{key}")

        attribute ->
          %{request | params: Map.put(request.attributes || %{}, attribute.name, value)}
      end
    end)
  end

  defp parse_attributes(request), do: %{request | attributes: %{}}

  defp parse_relationships(
         %{
           resource: resource,
           body: %{"data" => %{"relationships" => relationships}}
         } = request
       )
       when is_map(relationships) do
    Enum.reduce(relationships, request, fn {name, value}, request ->
      with %{"data" => data} when is_map(data) or is_list(data) <- value,
           relationship when not is_nil(relationship) <- Ash.relationship(resource, name),
           {:ok, change_value} <- relationship_change_value(relationship, data) do
        %{
          request
          | relationships: Map.put(request.relationships || %{}, relationship.name, change_value)
        }
      else
        _ ->
          add_error(request, "invalid relationship: #{name}")
      end
    end)
  end

  defp parse_relationships(request), do: %{request | relationships: %{}}

  # TODO: To do this properly, this needs to be told what relationship is being requested.
  # TODO: there is validation that needs to be done here.
  defp parse_resource_identifiers(%{body: %{"data" => data}} = request)
       when is_list(data) do
    identifiers =
      for %{"id" => id, "type" => _type} = identifier <- data do
        case Map.fetch(identifier, "meta") do
          {:ok, meta} -> Map.put(meta, :id, id)
          _ -> %{id: id}
        end
      end

    %{request | resource_identifiers: identifiers}
  end

  defp parse_resource_identifiers(%{body: %{"data" => data}} = request)
       when is_nil(data) do
    request
  end

  defp parse_resource_identifiers(%{body: %{"data" => %{"id" => id, "type" => _type}}} = request) do
    %{request | resource_identifiers: %{id: id}}
  end

  defp parse_resource_identifiers(request) do
    %{request | resource_identifiers: nil}
  end

  defp relationship_change_value(%{cardinality: :many} = relationship, value)
       when is_list(value) do
    value
    |> Stream.map(&relationship_change_value(relationship, &1))
    |> Enum.reduce({:ok, []}, fn
      {:ok, change}, {:ok, changes} ->
        # TODO: This reverses changes which could be problematic
        {:ok, [change | changes]}

      {:error, change}, _ ->
        {:error, change}

      _, {:error, change} ->
        {:error, change}
    end)
  end

  defp relationship_change_value(%{name: name}, value) when is_list(value) do
    {:error, "supplied a list of related entities for a to_one relationship #{name}"}
  end

  defp relationship_change_value(%{cardinality: :many, name: name}, value)
       when not is_list(value) do
    {:error, "supplied a single related entity for a to_many relationship #{name}"}
  end

  defp relationship_change_value(_relationship, %{"id" => id, "type" => _type} = value) do
    case Map.fetch(value, "meta") do
      {:ok, meta} -> {:ok, Map.put(meta, :id, id)}
      _ -> {:ok, %{id: id}}
    end
  end

  defp relationship_change_value(%{cardinality: :one}, nil), do: {:ok, nil}

  defp relationship_change_value(%{name: name}, _) do
    {:error, "invalid change for relationship #{name}"}
  end
end
