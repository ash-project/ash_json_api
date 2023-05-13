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

  def serialize_many(request, paginator, includes, meta \\ nil) do
    data =
      case paginator do
        %{results: results} ->
          results

        other when is_list(other) ->
          other
      end

    data = Enum.map(data, &serialize_one_record(request, &1))
    json_api = %{version: "1.0"}

    links = many_links(request, paginator)

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
    |> add_if_defined(:status, to_string(error.status_code))
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
      type: AshJsonApi.Resource.Info.type(relationship.destination)
    }
    |> add_relationship_meta(record, source_record, relationship)
  end

  defp add_relationship_meta(payload, _row, _source_record, _relationship) do
    payload
    # case relationship.join_attributes do
    #   [] ->
    #     payload

    #   attributes ->
    #     destination_value = Map.get(row, relationship.destination_attribute)

    #     source_record
    #     |> Map.get(relationship.join_relationship)
    #     |> Enum.find(fn join_row ->
    #       Map.get(join_row, relationship.destination_attribute_on_join_resource) == destination_value
    #     end)
    #     |> case do
    #       nil ->
    #         Map.put(payload, :meta, %{})

    #       join_row ->
    #         Map.put(payload, :meta, Map.take(join_row, attributes))
    #     end
    # end
  end

  defp add_top_level_meta(payload, meta) when is_map(meta), do: Map.put(payload, :meta, meta)
  defp add_top_level_meta(payload, _), do: payload

  defp add_includes(payload, %{includes_keyword: []}, _), do: payload

  defp add_includes(payload, request, includes) do
    includes = Enum.map(includes, &serialize_one_record(request, &1))
    Map.put(payload, :included, includes)
  end

  defp many_links(request, %{results: _} = paginator) do
    uri = URI.parse(request.url)
    query = Conn.Query.decode(uri.query || "")

    %{
      first: first_link(uri, query, paginator),
      self: many_self_link(uri, query, paginator)
    }
    |> add_last_link(uri, query, paginator)
    |> add_prev_link(uri, query, paginator)
    |> add_next_link(uri, query, paginator)
  end

  defp many_links(%{url: url}, _), do: %{self: url}

  defp first_link(uri, query, paginator) do
    paginator =
      case paginator do
        %{after: _} -> %{paginator | after: nil, before: nil}
        %{offset: _} -> %{paginator | offset: nil}
      end

    new_query =
      query
      |> put_page_params(paginator)
      |> Conn.Query.encode()

    uri
    |> put_query(new_query)
    |> URI.to_string()
    |> encode_link()
  end

  defp many_self_link(uri, query, paginator) do
    new_query =
      query
      |> put_page_params(paginator)
      |> put_count_param(paginator)
      |> Conn.Query.encode()

    uri
    |> put_query(new_query)
    |> URI.to_string()
    |> encode_link()
  end

  defp put_count_param(query, %{count: count}) when is_integer(count) do
    Map.update(query, "page", %{count: count}, &Map.put(&1, :count, count))
  end

  defp put_count_param(query, _), do: query

  defp put_page_params(query, %{limit: nil, offset: offset}) when offset in [0, nil] do
    query
  end

  defp put_page_params(query, %{limit: limit, offset: offset}) when offset in [0, nil] do
    Map.put(query, "page", %{
      limit: limit
    })
  end

  defp put_page_params(query, %{limit: nil, offset: offset}) do
    Map.put(query, "page", %{
      offset: offset
    })
  end

  defp put_page_params(query, %{limit: limit, offset: offset}) do
    Map.put(query, "page", %{
      limit: limit,
      offset: offset
    })
  end

  defp put_page_params(query, %{after: after_keyset, limit: nil}) when is_binary(after_keyset) do
    Map.put(query, "page", %{after: after_keyset})
  end

  defp put_page_params(query, %{after: after_keyset, limit: limit})
       when is_binary(after_keyset) do
    Map.put(query, "page", %{after: after_keyset, limit: limit})
  end

  defp put_page_params(query, %{before: before_keyset, limit: nil})
       when is_binary(before_keyset) do
    Map.put(query, "page", %{before: before_keyset})
  end

  defp put_page_params(query, %{before: before_keyset, limit: limit})
       when is_binary(before_keyset) do
    Map.put(query, "page", %{before: before_keyset, limit: limit})
  end

  defp put_page_params(query, %{limit: limit}) when is_integer(limit),
    do: Map.put(query, "page", %{limit: limit})

  defp put_page_params(query, _), do: query

  defp add_next_link(links, _uri, _query, %{offset: offset, limit: limit, total: total})
       when not is_nil(total) and not is_nil(offset) and offset + limit >= total,
       do: links

  defp add_next_link(links, _uri, _query, %{offset: offset, limit: limit, total: total})
       when not is_nil(total) and is_nil(offset) and limit >= total,
       do: links

  defp add_next_link(links, uri, query, %{offset: _} = paginator) do
    if Enum.count(paginator.results) < paginator.limit do
      links
    else
      new_query =
        query
        |> put_page_params(next_page(paginator))
        |> Conn.Query.encode()

      link =
        uri
        |> put_query(new_query)
        |> URI.to_string()
        |> encode_link()

      Map.put(links, :next, link)
    end
  end

  defp add_next_link(links, _uri, _query, %{results: [], after: _}) do
    links
  end

  defp add_next_link(links, uri, query, %{results: results, after: _} = paginator) do
    new_query =
      query
      |> put_page_params(%{paginator | after: List.last(results).metadata.keyset})
      |> Conn.Query.encode()

    link =
      uri
      |> put_query(new_query)
      |> URI.to_string()
      |> encode_link()

    Map.put(links, :next, link)
  end

  defp next_page(%{limit: nil} = paginator), do: paginator

  defp next_page(%{limit: limit, offset: offset} = paginator),
    do: %{paginator | offset: limit + (offset || 0)}

  defp add_prev_link(links, _uri, _query, %{offset: offset}) when offset in [0, nil], do: links

  defp add_prev_link(links, _uri, _query, %{results: [], after: _}) do
    links
  end

  defp add_prev_link(links, uri, query, %{results: results, after: _} = paginator) do
    new_query =
      query
      |> put_page_params(%{paginator | after: List.first(results).metadata.keyset})
      |> Conn.Query.encode()

    link =
      uri
      |> put_query(new_query)
      |> URI.to_string()
      |> encode_link()

    Map.put(links, :next, link)
  end

  defp add_prev_link(links, uri, query, paginator) do
    new_query =
      query
      |> put_page_params(prev_page(paginator))
      |> Conn.Query.encode()

    link =
      uri
      |> put_query(new_query)
      |> URI.to_string()
      |> encode_link()

    Map.put(links, :prev, link)
  end

  defp prev_page(paginator) do
    offset =
      if paginator.limit do
        max(paginator.offset - (paginator.limit || 0), 0)
      else
        0
      end

    %{paginator | offset: offset}
  end

  defp add_last_link(links, _uri, _query, %{count: nil}) do
    links
  end

  defp add_last_link(links, uri, query, %{count: total, limit: limit}) do
    new_query =
      query
      |> Map.put("page", %{
        limit: limit,
        offset: total - limit
      })
      |> Conn.Query.encode()

    link =
      uri
      |> put_query(new_query)
      |> URI.to_string()
      |> encode_link()

    Map.put(links, "last", link)
  end

  defp add_last_link(links, _, _, _), do: links

  defp one_links(request) do
    %{
      self: encode_link(request.url)
    }
  end

  defp serialize_one_record(request, %resource{} = record) do
    %{
      id: AshJsonApi.Resource.encode_primary_key(record),
      type: AshJsonApi.Resource.Info.type(resource),
      attributes: serialize_attributes(request, record),
      relationships: serialize_relationships(request, record),
      links: %{} |> add_one_record_self_link(request, record)
    }
    |> add_meta(record)
  end

  defp add_one_record_self_link(links, request, %resource{} = record) do
    resource
    |> AshJsonApi.Resource.route(%{type: :get, primary?: true})
    |> case do
      nil ->
        links

      %{route: route} ->
        link =
          request
          |> with_path_params(%{"id" => AshJsonApi.Resource.encode_primary_key(record)})
          |> at_host(route)

        Map.put(links, "self", link)
    end
  end

  defp add_meta(json_record, record) do
    meta =
      %{}
      |> add_keyset(record)

    Map.put(json_record, :meta, meta)
  end

  defp add_keyset(meta, %{metadata: %{keyset: keyset}}) do
    Map.put(meta, :keyset, keyset)
  end

  defp add_keyset(meta, _), do: meta

  defp serialize_relationships(request, %resource{} = record) do
    resource
    |> Ash.Resource.Info.public_relationships()
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

  defp add_relationship_link(links, request, %resource{} = record, relationship) do
    resource
    |> AshJsonApi.Resource.route(%{
      relationship: relationship.name,
      primary?: true,
      action_type: :relationship
    })
    |> case do
      nil ->
        links

      %{route: route} ->
        link =
          request
          |> with_path_params(%{"id" => AshJsonApi.Resource.encode_primary_key(record)})
          |> at_host(route)

        Map.put(links, "self", link)
    end
  end

  defp add_related_link(links, request, %resource{} = record, relationship) do
    resource
    |> AshJsonApi.Resource.route(%{
      relationship: relationship.name,
      primary?: true,
      action_type: :get_related
    })
    |> case do
      nil ->
        links

      %{route: route} ->
        link =
          request
          |> with_path_params(%{"id" => AshJsonApi.Resource.encode_primary_key(record)})
          |> at_host(route)

        Map.put(links, "related", link)
    end
  end

  defp add_linkage(payload, record, %{destination: destination, cardinality: :one, name: name}) do
    case record do
      %{__linkage__: %{^name => [%{id: id}]}} ->
        Map.put(payload, :data, %{id: id, type: AshJsonApi.Resource.Info.type(destination)})

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
        type = AshJsonApi.Resource.Info.type(destination)

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
    path =
      if request.json_api_prefix do
        if route do
          Path.join(request.json_api_prefix, route)
        else
          request.json_api_prefix
        end
      else
        route || ""
      end

    request.url
    |> URI.parse()
    |> Map.put(:query, nil)
    |> Map.put(:path, "/" <> path)
    |> Map.update!(:path, &replace_path_params(&1, request))
    |> URI.to_string()
    |> encode_link()
  end

  defp put_query(uri, query) do
    if query == "" do
      Map.put(uri, :query, nil)
    else
      Map.put(uri, :query, query)
    end
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

  defp field_type_from_aggregate(resource, agg) do
    if agg.field do
      related = Ash.Resource.Info.related(resource, agg.relationship_path)
      field = Ash.Resource.Info.field(related, agg.field)

      if field do
        field.type
      end
    end
  end

  defp serialize_attributes(_, nil), do: nil

  defp serialize_attributes(request, records) when is_list(records) do
    Enum.map(records, &serialize_attributes(request, &1))
  end

  defp serialize_attributes(request, %resource{} = record) do
    fields =
      Map.get(request.fields, resource) || Map.get(request.route, :default_fields) ||
        default_attributes(resource)

    Enum.reduce(fields, %{}, fn field, acc ->
      if AshJsonApi.Resource.only_primary_key?(resource, field) do
        acc
      else
        field = Ash.Resource.Info.field(resource, field)

        type =
          case field do
            %Ash.Resource.Aggregate{} = agg ->
              field_type = field_type_from_aggregate(resource, agg)

              {:ok, type} = Ash.Query.Aggregate.kind_to_type(agg.kind, field_type)
              type

            nil ->
              nil

            attribute ->
              attribute.type
          end

        cond do
          !field ->
            acc

          Ash.Type.embedded_type?(type) ->
            Map.put(
              acc,
              field.name,
              serialize_attributes(%{fields: %{}, route: %{}}, Map.get(record, field.name))
            )

          true ->
            Map.put(acc, field.name, Map.get(record, field.name))
        end
      end
    end)
  end

  defp default_attributes(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.map(& &1.name)
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
