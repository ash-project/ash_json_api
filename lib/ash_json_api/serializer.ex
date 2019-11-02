defmodule AshJsonApi.Serializer do
  def serialize_to_many_relationship(request, source_record, relationship, records) do
    links =
      %{self: at_host(request, request.url)}
      |> add_related_link(request, source_record, relationship)

    %{
      links: links,
      data: Enum.map(records, &serialize_relationship_data(&1, source_record, relationship))
    }
    |> Jason.encode!()
  end

  def serialize_to_one_relationship(request, source_record, relationship, record) do
    links =
      %{self: at_host(request, request.url)}
      |> add_related_link(request, source_record, relationship)

    %{
      links: links,
      data: serialize_relationship_data(record, source_record, relationship)
    }
    |> Jason.encode!()
  end

  def serialize_many(request, paginator, records, includes, meta \\ nil) do
    data = Enum.map(records, &serialize_one_record(request, &1))
    json_api = %{version: "1.0"}
    links = many_links(request, paginator)

    %{data: data, json_api: json_api, links: links}
    |> add_includes(request, includes)
    |> add_top_level_meta(meta)
    |> Jason.encode!()
  end

  def serialize_one(request, record, includes, meta \\ nil)

  def serialize_one(request, nil, _, meta) do
    json_api = %{version: "1.0"}
    links = one_links(request)

    %{data: nil, json_api: json_api, links: links}
    |> add_top_level_meta(meta)
    |> Jason.encode!()
  end

  def serialize_one(request, record, includes, meta) do
    data = serialize_one_record(request, record)
    json_api = %{version: "1.0"}
    links = one_links(request)

    %{data: data, json_api: json_api, links: links}
    |> add_includes(request, includes)
    |> add_top_level_meta(meta)
    |> Jason.encode!()
  end

  defp serialize_relationship_data(record, source_record, relationship) do
    %{
      id: record.id,
      type: Ash.type(relationship.destination)
    }
    |> add_relationship_meta(record, source_record, relationship)
  end

  defp add_relationship_meta(payload, %{__join_row__: join_row}, %source_resource{}, %{name: name}) do
    case AshJsonApi.join_fields(source_resource, name) do
      [_ | _] = fields ->
        meta =
          Enum.reduce(fields, %{}, fn field, acc ->
            Map.put(acc, field, Map.get(join_row, field))
          end)

        Map.put(payload, :meta, meta)

      _ ->
        payload
    end
  end

  defp add_relationship_meta(payload, _, _, _) do
    payload
  end

  defp add_top_level_meta(payload, meta) when is_map(meta), do: Map.put(payload, :meta, meta)
  defp add_top_level_meta(payload, _), do: payload

  defp add_includes(payload, _request, []), do: payload

  defp add_includes(payload, request, includes) do
    includes = Enum.map(includes, &serialize_one_record(request, &1))
    Map.put(payload, :includes, includes)
  end

  defp many_links(%{url: url} = request, paginator) do
    uri = URI.parse(request.url)
    query = Plug.Conn.Query.decode(uri.query || "")

    %{
      first: first_link(uri, query, paginator),
      self: url
    }
    |> add_last_link(uri, query, paginator)
    |> add_prev_link(uri, query, paginator)
    |> add_next_link(uri, query, paginator)
  end

  defp first_link(uri, query, paginator) do
    new_query =
      query
      |> Map.put("page", %{
        limit: paginator.limit,
        offset: 0
      })
      |> Plug.Conn.Query.encode()

    uri
    |> Map.put(:query, new_query)
    |> URI.to_string()
  end

  defp add_next_link(links, _uri, _query, %{offset: offset, limit: limit, total: total})
       when not is_nil(total) and offset + limit >= total,
       do: links

  defp add_next_link(links, uri, query, %{offset: offset, limit: limit}) do
    new_query =
      query
      |> Map.put("page", %{
        limit: limit + offset,
        offset: offset
      })
      |> Plug.Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()

    Map.put(links, :next, link)
  end

  defp add_next_link(links, uri, query, paginator) do
    new_query =
      query
      |> Map.put("page", %{
        limit: paginator.limit,
        offset: 0
      })
      |> Plug.Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()

    Map.put(links, :prev, link)
  end

  defp add_prev_link(links, _uri, _query, %{offset: 0}), do: links

  defp add_prev_link(links, uri, query, paginator) do
    new_query =
      query
      |> Map.put("page", %{
        limit: paginator.limit,
        offset: 0
      })
      |> Plug.Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()

    Map.put(links, :prev, link)
  end

  defp add_last_link(links, _uri, _query, %{total: nil}) do
    links
  end

  defp add_last_link(links, uri, query, %{total: total, limit: limit}) do
    new_query =
      query
      |> Map.put("page", %{
        limit: limit,
        offset: total - limit
      })
      |> Plug.Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()

    Map.put(links, "last", link)
  end

  defp one_links(request) do
    %{
      self: request.url
    }
  end

  defp serialize_one_record(request, record) do
    resource = Ash.to_resource(record)

    %{
      id: record.id,
      type: Ash.type(resource),
      attributes: serialize_attributes(record),
      relationships: serialize_relationships(request, record),
      links: %{} |> add_one_record_self_link(request, record)
    }
    |> add_meta(record)
  end

  defp add_one_record_self_link(links, request, %resource{id: id}) do
    resource
    |> AshJsonApi.route(%{action: :get, primary?: true})
    |> case do
      nil ->
        links

      %{route: route} ->
        link =
          request
          |> with_path_params(%{"id" => id})
          |> at_host(route)

        Map.put(links, "self", link)
    end
  end

  defp add_meta(json_record, %{__json_api_meta__: meta}) when is_map(meta),
    do: Map.put(json_record, :meta, meta)

  defp add_meta(json_record, _), do: json_record

  defp serialize_relationships(request, record) do
    resource = Ash.to_resource(record)
    fields = AshJsonApi.fields(resource)

    resource
    |> Ash.relationships()
    |> Stream.filter(&(&1.name in fields))
    |> Enum.into(%{}, fn relationship ->
      value =
        %{
          links: relationship_links(record, request, relationship),
          meta: %{}
        }
        |> add_linkage(record, relationship)

      {relationship.name, value}
    end)
  end

  defp relationship_links(record, request, relationship) do
    %{}
    |> add_relationship_link(request, record, relationship)
    |> add_related_link(request, record, relationship)
  end

  defp add_relationship_link(links, request, %resource{id: id}, relationship) do
    resource
    |> AshJsonApi.route(%{
      relationship: relationship.name,
      primary?: true,
      action: :get_relationship
    })
    |> case do
      nil ->
        links

      %{route: route} ->
        link =
          request
          |> with_path_params(%{"id" => id})
          |> at_host(route)

        Map.put(links, "relationship", link)
    end
  end

  defp add_related_link(links, request, %resource{id: id}, relationship) do
    resource
    |> AshJsonApi.route(%{relationship: relationship.name, primary?: true, action: :get_related})
    |> case do
      nil ->
        links

      %{route: route} ->
        link =
          request
          |> with_path_params(%{"id" => id})
          |> at_host(route)

        Map.put(links, "related", link)
    end
  end

  defp add_linkage(payload, record, %{destination: destination, cardinality: :one, name: name}) do
    case record do
      %{__linkage__: %{^name => [%{id: id}]}} ->
        Map.put(payload, :data, %{id: id, type: Ash.type(destination)})

      # There could be another case here if a bug in the system gave us a list
      # of more than one shouldn't happen though

      _ ->
        payload
    end
  end

  defp add_linkage(
         payload,
         record,
         %{destination: destination, cardinality: :many, name: name} = relationship
       ) do
    case record do
      %{__linkage__: %{^name => linkage}} ->
        type = Ash.type(destination)

        Map.put(
          payload,
          :data,
          Enum.map(
            linkage,
            &(%{id: &1.id, type: type} |> add_relationship_meta(&1, record, relationship))
          )
        )

      _ ->
        payload
    end
  end

  defp with_path_params(request, params) do
    Map.update!(request, :path_params, &Map.merge(&1, params))
  end

  defp at_host(request, route) do
    request.url
    |> URI.parse()
    |> Map.put(:query, nil)
    |> Map.put(:path, "/" <> Path.join(request.json_api_prefix, route))
    |> Map.update!(:path, fn path ->
      path
      |> Path.split()
      |> Enum.map(fn path_element ->
        if String.starts_with?(path_element, ":") do
          "replacing #{path_element}"
          Map.get(request.path_params, String.slice(path_element, 1..-1)) || ""
        else
          path_element
        end
      end)
      |> Path.join()
    end)
    |> URI.to_string()
  end

  defp serialize_attributes(%resource{} = record) do
    fields = AshJsonApi.fields(resource)

    resource
    |> Ash.attributes()
    |> Stream.filter(&(&1.name in fields))
    |> Stream.reject(&(&1.name == :id))
    |> Enum.into(%{}, fn attribute ->
      {attribute.name, Map.get(record, attribute.name)}
    end)
  end
end
