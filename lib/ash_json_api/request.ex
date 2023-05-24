defmodule AshJsonApi.Request do
  @moduledoc false
  require Logger

  alias AshJsonApi.Error.{
    InvalidBody,
    InvalidField,
    InvalidHeader,
    InvalidQuery,
    InvalidType,
    UnacceptableMediaType,
    UnsupportedMediaType
  }

  alias AshJsonApi.Includes
  alias Plug.Conn

  require Ash.Query

  import Ash.PlugHelpers, only: [get_actor: 1, get_tenant: 1, get_context: 1]

  defstruct [
    :api,
    :action,
    :resource,
    :path_params,
    :query_params,
    :includes,
    :includes_keyword,
    :filter,
    :resource_identifiers,
    :body,
    :url,
    :json_api_prefix,
    :actor,
    :tenant,
    :context,
    :schema,
    :req_headers,
    :relationship,
    :route,
    attributes: %{},
    arguments: %{},
    filter_included: %{},
    sort: [],
    fields: %{},
    errors: [],
    # assigns is used by controllers to store state while piping
    # the request around
    assigns: %{}
  ]

  @type t() :: %__MODULE__{}

  @type error :: {:error, AshJsonApi.Error.InvalidIncludes.t()}

  @spec from(
          conn :: Plug.Conn.t(),
          resource :: Ash.Resource.t(),
          action :: atom,
          Ash.Api.t(),
          AshJsonApi.Resource.Route.t()
        ) ::
          t
  def from(conn, resource, action, api, route) do
    includes = Includes.Parser.parse_and_validate_includes(resource, conn.query_params)

    %__MODULE__{
      api: api,
      resource: resource,
      action: action,
      includes: includes.allowed,
      url: Conn.request_url(conn),
      path_params: conn.path_params,
      query_params: conn.query_params,
      req_headers: conn.req_headers,
      actor: get_actor(conn),
      tenant: get_tenant(conn),
      context: get_context(conn),
      body: conn.body_params,
      schema: AshJsonApi.JsonSchema.route_schema(route, api, resource),
      relationship: route.relationship,
      route: route,
      json_api_prefix: AshJsonApi.Api.Info.prefix(api)
    }
    |> validate_params()
    |> validate_href_schema()
    |> validate_req_headers()
    |> validate_body()
    |> parse_fields()
    |> parse_filter_included()
    |> parse_includes()
    |> parse_filter()
    |> parse_sort()
    |> parse_attributes()
    |> parse_read_arguments()
    |> parse_relationships()
    |> parse_resource_identifiers()
  end

  def load_opts(request) do
    [
      actor: request.actor,
      authorize?: AshJsonApi.Api.Info.authorize?(request.api),
      tenant: request.tenant
    ]
  end

  def opts(request, merge \\ []) do
    page_params = Map.get(request.assigns, :page)

    opts = [
      actor: request.actor,
      authorize?: AshJsonApi.Api.Info.authorize?(request.api),
      tenant: request.tenant
    ]

    opts =
      if page_params do
        Keyword.put(opts, :page, page_params)
      else
        opts
      end

    Keyword.merge(merge, opts)
  end

  def assign(request, key, value) do
    %{request | assigns: Map.put(request.assigns, key, value)}
  end

  def update_assign(request, key, default, function) do
    %{request | assigns: Map.update(request.assigns, key, default, function)}
  end

  def add_error(request, error_or_errors, operation, resource \\ nil) do
    resource = resource || request.resource

    error_or_errors
    |> List.wrap()
    |> Enum.reduce(request, fn error, request ->
      new_errors =
        AshJsonApi.Error.to_json_api_errors(resource, error, operation) ++ request.errors

      %{request | errors: new_errors}
    end)
  end

  defp validate_body(%{body: body, schema: %{"schema" => schema}} = request) do
    json_xema = JsonXema.new(schema)

    json_xema
    |> JsonXema.validate(body)
    |> case do
      :ok ->
        request

      {:error, error} ->
        add_error(request, InvalidBody.new(json_xema_error: error), request.route.type)
    end
  end

  defp validate_body(request) do
    request
  end

  defp validate_req_headers(
         %{req_headers: req_headers, schema: %{"headerSchema" => schema}} = request
       ) do
    json_xema = JsonXema.new(schema)

    headers = Enum.group_by(req_headers, &elem(&1, 0), &elem(&1, 1))

    json_xema
    |> JsonXema.validate(headers)
    |> case do
      :ok ->
        request

      {:error, error} ->
        add_error(request, InvalidHeader.new(json_xema_error: error), request.route.type)
    end
    |> validate_accept_header()
    |> validate_content_type_header()
  end

  defp validate_content_type_header(%{req_headers: headers} = request) do
    headers
    |> Enum.filter(fn {header, _value} ->
      header == "content-type"
    end)
    |> Enum.map(fn {_header, value} ->
      Conn.Utils.media_type(value)
    end)
    |> case do
      [] ->
        request

      values ->
        any_content_type_supported? =
          Enum.any?(values, fn
            {:ok, "*", _, _} ->
              true

            _ ->
              false
          end)

        json_api_content_type_supported? =
          Enum.all?(values, fn
            {:ok, "*", _, _} ->
              true

            {:ok, "application", "vnd.api+json", params} ->
              valid_header_params?(params)

            _ ->
              false
          end)

        if any_content_type_supported? || json_api_content_type_supported? do
          request
        else
          add_error(request, UnacceptableMediaType.new([]), request.route.type)
        end
    end
  end

  defp validate_accept_header(%{req_headers: headers} = request) do
    accepts_json_api? =
      headers
      |> Enum.filter(fn {header, _value} -> header == "accept" end)
      |> Enum.flat_map(fn {_, value} ->
        String.split(value, ",")
      end)
      |> Enum.map(fn
        "" ->
          ""

        value ->
          Conn.Utils.media_type(value)
      end)
      |> Enum.filter(fn
        {:ok, "application", "vnd.api+json", _} -> true
        _ -> false
      end)
      |> case do
        [] ->
          true

        headers ->
          Enum.any?(headers, fn {:ok, "application", "vnd.api+json", params} ->
            Application.get_env(:ash_json_api, :allow_all_media_type_params?, false) ||
              valid_header_params?(params)
          end)
      end

    if accepts_json_api? do
      request
    else
      add_error(request, UnsupportedMediaType.new([]), request.route.type)
    end
  end

  defp valid_header_params?(params) do
    params
    |> Map.keys()
    |> Enum.sort()
    |> case do
      [] ->
        true

      ["ext"] ->
        true

      ["profile"] ->
        true

      ["ext", "profile"] ->
        true

      _ ->
        false
    end
  end

  defp validate_params(%{query_params: query_params, path_params: path_params} = request) do
    if Enum.any?(Map.keys(query_params), &Map.has_key?(path_params, &1)) do
      add_error(request, "conflict path and query params", request.route.type)
    else
      request
    end
  end

  defp validate_href_schema(%{schema: nil} = request) do
    add_error(request, "no schema found", request.route.type)
  end

  defp validate_href_schema(
         %{
           schema: %{"hrefSchema" => schema},
           query_params: query_params,
           path_params: path_params
         } = request
       ) do
    json_xema = JsonXema.new(schema)

    case JsonXema.validate(json_xema, Map.merge(path_params, query_params)) do
      :ok ->
        request

      {:error, error} ->
        add_error(request, InvalidQuery.new(json_xema_error: error), request.route.type)
    end
  end

  defp parse_filter_included(
         %{resource: resource, query_params: %{"filter_included" => filter_included}} = request
       )
       when is_map(filter_included) do
    Enum.reduce(filter_included, request, fn {relationship_path, filter_statement}, request ->
      path = String.split(relationship_path)

      case public_related(resource, path) do
        nil ->
          add_error(request, "Invalid filter included", request.route.type)

        _ ->
          path = Enum.map(path, &String.to_existing_atom/1)
          %{request | filter_included: Map.put(request.filter_included, path, filter_statement)}
      end
    end)
  end

  defp parse_filter_included(request), do: request

  defp parse_fields(%{resource: resource, query_params: %{"fields" => fields}} = request)
       when is_binary(fields) do
    add_fields(request, resource, fields, false)
  end

  defp parse_fields(%{query_params: %{"fields" => fields}} = request) when is_map(fields) do
    Enum.reduce(fields, request, fn {type, fields}, request ->
      request.api
      |> Ash.Api.Info.resources()
      |> Enum.find(&(AshJsonApi.Resource.Info.type(&1) == type))
      |> case do
        nil ->
          add_error(request, InvalidType.new(type: type), request.route.type)

        resource ->
          add_fields(request, resource, fields, true)
      end
    end)
  end

  defp parse_fields(request), do: request

  if function_exported?(Ash.Resource.Info, :public_related, 2) do
    defp public_related(resource, relationship) do
      Ash.Resource.Info.public_related(resource, relationship)
    end
  else
    defp public_related(resource, relationship) when not is_list(relationship) do
      public_related(resource, [relationship])
    end

    defp public_related(resource, []), do: resource

    defp public_related(resource, [path | rest]) do
      case Ash.Resource.Info.public_relationship(resource, path) do
        %{destination: destination} -> public_related(destination, rest)
        nil -> nil
      end
    end
  end

  defp add_fields(request, resource, fields, parameter?) do
    type = AshJsonApi.Resource.Info.type(resource)

    fields
    |> String.split(",")
    |> Enum.reduce(request, fn key, request ->
      cond do
        attr = Ash.Resource.Info.public_attribute(resource, key) ->
          fields = Map.update(request.fields, resource, [attr.name], &[attr.name | &1])
          %{request | fields: fields}

        rel = Ash.Resource.Info.public_relationship(resource, key) ->
          fields = Map.update(request.fields, resource, [rel.name], &[rel.name | &1])
          %{request | fields: fields}

        agg = Ash.Resource.Info.public_aggregate(resource, key) ->
          fields = Map.update(request.fields, resource, [agg.name], &[agg.name | &1])
          %{request | fields: fields}

        true ->
          add_error(
            request,
            InvalidField.new(type: type, parameter?: parameter?),
            request.route.type
          )
      end
    end)
  end

  defp parse_filter(%{query_params: %{"filter" => filter}} = request)
       when is_map(filter) do
    %{request | filter: filter}
  end

  defp parse_filter(%{query_params: %{"filter" => _}} = request) do
    add_error(request, "invalid filter", request.route.type)
  end

  defp parse_filter(request), do: %{request | filter: %{}}

  defp parse_sort(%{query_params: %{"sort" => sort_string}, resource: resource} = request)
       when is_bitstring(sort_string) do
    sort_string
    |> String.split(",")
    |> case do
      [] ->
        request

      sort ->
        sort
        |> Enum.reverse()
        |> Enum.reduce(request, fn field, request ->
          {order, field_name} = trim_sort_order(field)

          cond do
            attr = Ash.Resource.Info.public_attribute(resource, field_name) ->
              %{request | sort: [{attr.name, order} | request.sort]}

            agg = Ash.Resource.Info.public_aggregate(resource, field_name) ->
              %{request | sort: [{agg.name, order} | request.sort]}

            true ->
              add_error(request, "invalid sort #{field}", request.route.type)
          end
        end)
    end
  end

  defp parse_sort(%{query_params: %{"sort" => _sort_string}} = request) do
    add_error(request, "invalid sort string", request.route.type)
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
        %{request | includes: includes, includes_keyword: includes_to_keyword(request, allowed)}

      %{allowed: _allowed, disallowed: _disallowed} ->
        add_error(request, "invalid includes", request.route.type)
    end
  end

  defp includes_to_keyword(request, includes) do
    includes
    |> Enum.reduce([], fn path, acc ->
      put_path(acc, path)
    end)
    |> set_include_queries(request.fields, request.filter_included, request.resource)
  end

  defp set_include_queries(includes, fields, filters, resource, path \\ []) do
    Enum.map(includes, fn {key, nested} ->
      related = public_related(resource, key)
      nested = set_include_queries(nested, fields, filters, related, path ++ [key])

      load =
        fields
        |> Map.get(related)
        |> Kernel.||([])
        |> Kernel.++(nested)

      new_query =
        related
        |> Ash.Query.new()
        |> Ash.Query.load(load)

      filtered_query =
        case Map.fetch(filters, path ++ [key]) do
          {:ok, filter} ->
            Ash.Query.filter(new_query, ^filter)

          :error ->
            new_query
        end

      {key, filtered_query}
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
         %{resource: resource, action: action, body: %{"data" => %{"attributes" => attributes}}} =
           request
       )
       when is_map(attributes) do
    Enum.reduce(attributes, request, fn {key, value}, request ->
      cond do
        arg =
            Enum.find(action.arguments, fn argument ->
              to_string(argument.name) == key
            end) ->
          %{request | arguments: Map.put(request.arguments || %{}, arg.name, value)}

        attr = Ash.Resource.Info.public_attribute(resource, key) ->
          %{request | attributes: Map.put(request.attributes || %{}, attr.name, value)}

        true ->
          # The json_schema will have an error here
          request
      end
    end)
  end

  defp parse_attributes(request), do: %{request | attributes: %{}, arguments: %{}}

  defp parse_read_arguments(%{action: %{type: :read} = action} = request) do
    action.arguments
    |> Enum.reject(& &1.private?)
    |> Enum.reduce(request, fn argument, request ->
      name = to_string(argument.name)

      with :error <- Map.fetch(request.query_params, name),
           :error <- Map.fetch(request.path_params, name) do
        request
      else
        {:ok, value} ->
          %{request | arguments: Map.put(request.arguments, argument.name, value)}
      end
    end)
  end

  defp parse_read_arguments(request), do: request

  defp parse_relationships(
         %{
           body: %{"data" => %{"relationships" => relationships}},
           action: action,
           route: %{
             relationship_arguments: relationship_arguments
           }
         } = request
       )
       when is_map(relationships) do
    Enum.reduce(relationships, request, fn {name, value}, request ->
      with %{"data" => data} when is_map(data) or is_list(data) <- value,
           arg when not is_nil(arg) <-
             Enum.find(
               action.arguments,
               &(to_string(&1.name) == name &&
                   has_relationship_argument?(relationship_arguments, &1.name))
             ),
           {:ok, change_value} <-
             relationship_change_value(data) do
        case find_relationship_argument(relationship_arguments, arg.name) do
          {:id, _arg} ->
            %{
              request
              | arguments: Map.put(request.arguments || %{}, arg.name, change_value["id"])
            }

          _ ->
            %{
              request
              | arguments: Map.put(request.arguments || %{}, arg.name, change_value)
            }
        end
      else
        _ ->
          add_error(request, "invalid relationship input: #{name}", request.route.type)
      end
    end)
  end

  defp parse_relationships(request), do: request

  defp find_relationship_argument(relationship_arguments, name) do
    Enum.find(relationship_arguments, fn
      {:id, ^name} -> true
      ^name -> true
      _ -> false
    end)
  end

  defp has_relationship_argument?(relationship_arguments, name) do
    Enum.any?(relationship_arguments, fn
      {:id, ^name} -> true
      ^name -> true
      _ -> false
    end)
  end

  defp parse_resource_identifiers(%{body: %{"data" => data}} = request)
       when is_list(data) do
    identifiers =
      for %{"id" => id, "type" => _type} = identifier <- data do
        case Map.fetch(identifier, "meta") do
          {:ok, meta} -> {%{id: id}, meta}
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

  defp relationship_change_value(value)
       when is_list(value) do
    value
    |> Stream.map(&relationship_change_value(&1))
    |> Enum.reduce({:ok, []}, fn
      {:ok, change}, {:ok, changes} ->
        {:ok, [change | changes]}

      {:error, change}, _ ->
        {:error, change}

      _, {:error, change} ->
        {:error, change}
    end)
    |> case do
      {:ok, changes} ->
        {:ok, Enum.reverse(changes)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp relationship_change_value(%{"id" => id} = value) do
    case Map.fetch(value, "meta") do
      {:ok, meta} -> {:ok, Map.put(meta, "id", id)}
      _ -> {:ok, %{"id" => id}}
    end
  end

  defp relationship_change_value(value) when value in [nil, %{}] do
    {:ok, nil}
  end

  defp relationship_change_value(_) do
    :error
  end
end
