defmodule AshJsonApi.Serializer do
  @moduledoc false

  alias Plug.Conn

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

  def serialize_many(request, paginator, includes, paginate? \\ true, meta \\ nil) do
    data = Enum.map(paginator.results, &serialize_one_record(request, &1))
    json_api = %{version: "1.0"}

    links = many_links(request, paginator, paginate?)

    %{data: data, jsonapi: json_api, links: links}
    |> add_includes(request, includes)
    |> add_top_level_meta(meta)
    |> Jason.encode!()
  end

  def serialize_one(request, record, includes, meta \\ nil)

  def serialize_one(request, nil, _, meta) do
    json_api = %{version: "1.0"}
    links = one_links(request)

    %{data: nil, jsonapi: json_api, links: links}
    |> add_top_level_meta(meta)
    |> Jason.encode!()
  end

  def serialize_one(request, record, includes, meta) do
    data = serialize_one_record(request, record)
    json_api = %{version: "1.0"}
    links = one_links(request)

    %{data: data, jsonapi: json_api, links: links}
    |> add_includes(request, includes)
    |> add_top_level_meta(meta)
    |> Jason.encode!()
  end

  def serialize_errors(request, error_or_errors, meta \\ nil) do
    json_api = %{version: "1.0"}

    errors =
      error_or_errors
      |> List.wrap()
      |> Enum.map(&serialize_one_error(&1, request))

    %{errors: errors, jsonapi: json_api}
    |> add_top_level_meta(meta)
    |> Jason.encode!()
  end

  defp serialize_one_error(error, request) do
    %{}
    |> add_if_defined(:id, error.id)
    |> add_if_defined(:status, error.status)
    |> add_if_defined(:code, error.code)
    |> add_if_defined(:title, error.title)
    |> add_if_defined(:detail, error.detail)
    |> add_if_defined([:source, :pointer], error.source_pointer)
    |> add_if_defined([:source, :parameter], error.source_parameter)
    |> add_if_defined(:meta, error.meta)
    |> add_about_link(error.about, request)
  end

  defp add_about_link(payload, about, request) when is_bitstring(about) do
    url = at_host(request, about)
    Map.put(payload, :links, %{about: url})
  end

  defp add_about_link(payload, _, _request), do: payload

  defp add_if_defined(params, _, :undefined) do
    params
  end

  defp add_if_defined(params, [key1, key2], value) do
    params
    |> Map.put_new(key1, %{})
    |> Map.update!(key1, &Map.put(&1, key2, value))
  end

  defp add_if_defined(params, key, value) do
    Map.put(params, key, value)
  end

  defp serialize_relationship_data(record, source_record, relationship) do
    %{
      id: record.id,
      type: AshJsonApi.type(relationship.destination)
    }
    |> add_relationship_meta(record, source_record, relationship)
  end

  defp add_relationship_meta(payload, _row, _source, _relationship) do
    payload
  end

  defp add_top_level_meta(payload, meta) when is_map(meta), do: Map.put(payload, :meta, meta)
  defp add_top_level_meta(payload, _), do: payload

  defp add_includes(payload, %{includes_keyword: []}, _), do: payload

  defp add_includes(payload, request, includes) do
    includes = Enum.map(includes, &serialize_one_record(request, &1))
    Map.put(payload, :included, includes)
  end

  defp many_links(%{url: url} = request, paginator, paginate?) do
    uri = URI.parse(request.url)
    query = Conn.Query.decode(uri.query || "")

    if paginate? do
      %{
        first: first_link(uri, query, paginator),
        self: many_self_link(uri, query, paginator)
      }
      |> add_last_link(uri, query, paginator)
      |> add_prev_link(uri, query, paginator)
      |> add_next_link(uri, query, paginator)
    else
      %{
        self: url
      }
    end
  end

  defp first_link(uri, query, paginator) do
    new_query =
      query
      |> Map.put("page", %{
        limit: paginator.limit,
        offset: 0
      })
      |> Conn.Query.encode()

    uri
    |> Map.put(:query, new_query)
    |> URI.to_string()
    |> encode_link()
  end

  defp many_self_link(uri, query, paginator) do
    new_query =
      query
      |> Map.put("page", %{
        limit: paginator.limit,
        offset: paginator.offset
      })
      |> Conn.Query.encode()

    uri
    |> Map.put(:query, new_query)
    |> URI.to_string()
    |> encode_link()
  end

  defp add_next_link(links, _uri, _query, %{offset: offset, limit: limit, total: total})
       when not is_nil(total) and not is_nil(offset) and offset + limit >= total,
       do: links

  defp add_next_link(links, _uri, _query, %{offset: offset, limit: limit, total: total})
       when not is_nil(total) and is_nil(offset) and limit >= total,
       do: links

  defp add_next_link(links, uri, query, %{offset: offset, limit: limit})
       when not is_nil(limit) do
    new_query =
      query
      |> Map.put("page", %{
        limit: limit + (offset || 0),
        offset: offset
      })
      |> Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()
      |> encode_link()

    Map.put(links, :next, link)
  end

  defp add_next_link(links, uri, query, %{offset: offset}) do
    new_query =
      query
      |> Map.put("page", %{
        offset: offset
      })
      |> Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()
      |> encode_link()

    Map.put(links, :next, link)
  end

  defp add_prev_link(links, _uri, _query, %{offset: 0}), do: links

  defp add_prev_link(links, uri, query, paginator) do
    offset =
      if paginator.limit do
        max(paginator.limit - (paginator.offset || 0), 0)
      else
        0
      end

    new_query =
      query
      |> Map.put("page", %{
        limit: paginator.limit,
        offset: offset
      })
      |> Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()
      |> encode_link()

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
      |> Conn.Query.encode()

    link =
      uri
      |> Map.put(:query, new_query)
      |> URI.to_string()
      |> encode_link()

    Map.put(links, "last", link)
  end

  defp one_links(request) do
    %{
      self: encode_link(request.url)
    }
  end

  defp serialize_one_record(request, %resource{} = record) do
    %{
      id: record.id,
      type: AshJsonApi.type(resource),
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

  defp serialize_relationships(request, %resource{} = record) do
    fields = AshJsonApi.fields(resource)

    resource
    |> Ash.Resource.relationships()
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
        Map.put(payload, :data, %{id: id, type: AshJsonApi.type(destination)})

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
        type = AshJsonApi.type(destination)

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
    |> Map.update!(:path, &replace_path_params(&1, request))
    |> URI.to_string()
    |> encode_link()
  end

  defp replace_path_params(path, request) do
    path
    |> Path.split()
    |> Enum.map(fn path_element ->
      if String.starts_with?(path_element, ":") do
        Map.get(request.path_params, String.slice(path_element, 1..-1)) || ""
      else
        path_element
      end
    end)
    |> Path.join()
  end

  defp serialize_attributes(%resource{} = record) do
    fields = AshJsonApi.fields(resource)

    resource
    |> Ash.Resource.attributes()
    |> Stream.filter(&(&1.name in fields))
    |> Stream.reject(&(&1.name == :id))
    |> Enum.into(%{}, fn attribute ->
      {attribute.name, Map.get(record, attribute.name)}
    end)
  end

  defp encode_link(value) do
    value
    # value
    # |> URI.parse()
    # |> Map.update(:query, nil, fn query ->
    #   URI.encode_www_form(query)
    # end)
    # |> URI.to_string()
  end
end
