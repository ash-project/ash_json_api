defmodule AshJsonApi.Request do
  @moduledoc false
  require Logger

  alias AshJsonApi.Error.{
    InvalidBody,
    InvalidField,
    InvalidHeader,
    InvalidIncludes,
    InvalidQuery,
    InvalidRelationshipInput,
    InvalidType,
    UnacceptableMediaType,
    UnsupportedMediaType
  }

  alias AshJsonApi.Includes
  alias Plug.Conn

  require Ash.Query

  import Ash.PlugHelpers, only: [get_actor: 1, get_tenant: 1, get_context: 1]

  defstruct [
    :domain,
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
    sort_included: %{},
    sort: [],
    fields: %{},
    field_inputs: %{},
    errors: [],
    all_domains: [],
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
          Ash.Domain.t(),
          list(Ash.Domain.t()),
          AshJsonApi.Resource.Route.t(),
          String.t() | nil
        ) ::
          t
  def from(conn, resource, action, domain, all_domains, route, prefix) do
    includes = Includes.Parser.parse_and_validate_includes(resource, conn.query_params)

    {_, route_schema} =
      AshJsonApi.JsonSchema.route_schema(route, domain, resource, prefix: prefix)

    %__MODULE__{
      domain: domain,
      resource: resource,
      action: action,
      includes: includes.allowed,
      url: url(conn),
      path_params:
        Map.new(conn.path_params || %{}, fn
          {k, v} when is_binary(v) ->
            {k, URI.decode(v)}

          {k, v} ->
            {k, v}
        end),
      query_params: conn.query_params,
      req_headers: conn.req_headers,
      actor: get_actor(conn),
      tenant: get_tenant(conn),
      context: get_context(conn),
      body: conn.body_params,
      all_domains: all_domains,
      schema: route_schema,
      relationship: route.relationship,
      route: route,
      json_api_prefix: prefix || AshJsonApi.Domain.Info.prefix(domain)
    }
    |> validate_params()
    |> validate_href_schema()
    |> validate_req_headers()
    |> validate_body()
    |> parse_fields()
    |> parse_field_inputs()
    |> parse_filter_included()
    |> parse_sort_included()
    |> parse_includes()
    |> parse_filter()
    |> parse_sort()
    |> parse_attributes()
    |> parse_query_params()
    |> parse_action_arguments()
    |> parse_relationships()
    |> parse_resource_identifiers()
  end

  def load_opts(request) do
    [
      actor: request.actor,
      authorize?: AshJsonApi.Domain.Info.authorize?(request.domain),
      tenant: request.tenant
    ]
  end

  def load_opts(request, merge) do
    Keyword.merge(
      load_opts(request),
      merge
    )
  end

  if Application.compile_env(:ash_json_api, :authorize_update_destroy_with_error?) do
    def authorize_bulk_with(resource) do
      if Ash.DataLayer.data_layer_can?(resource, :expr_error) do
        :error
      else
        :filter
      end
    end
  else
    def authorize_bulk_with(_resource) do
      :filter
    end
  end

  def opts(request, merge \\ []) do
    page_params = Map.get(request.assigns, :page)

    opts = [
      actor: request.actor,
      domain: request.domain,
      authorize?: AshJsonApi.Domain.Info.authorize?(request.domain),
      tenant: request.tenant
    ]

    opts =
      if page_params && page_params != [] && request.action.pagination do
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
        AshJsonApi.Error.to_json_api_errors(request.domain, resource, error, operation) ++
          request.errors

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
        add_error(request, InvalidBody.exception(json_xema_error: error), request.route.type)
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
        add_error(request, InvalidHeader.exception(json_xema_error: error), request.route.type)
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
              Application.get_env(:ash_json_api, :allow_all_media_type_params?, false) ||
                valid_header_params?(params, :json)

            {:ok, "multipart", "x.ash+form-data", params} ->
              Application.get_env(:ash_json_api, :allow_all_media_type_params?, false) ||
                valid_header_params?(params, :multipart)

            _ ->
              false
          end)

        if any_content_type_supported? || json_api_content_type_supported? do
          request
        else
          add_error(request, UnacceptableMediaType.exception([]), request.route.type)
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
              valid_header_params?(params, :json)
          end)
      end

    if accepts_json_api? do
      request
    else
      add_error(request, UnsupportedMediaType.exception([]), request.route.type)
    end
  end

  @spec valid_header_params?(params :: Plug.Conn.Utils.params(), format :: :json | :multipart) ::
          boolean
  defp valid_header_params?(params, format) do
    params
    |> Map.keys()
    |> Enum.sort()
    |> then(
      case format do
        :json -> & &1
        :multipart -> &List.delete(&1, "boundary")
      end
    )
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
        add_error(request, InvalidQuery.exception(json_xema_error: error), request.route.type)
    end
  end

  defp parse_filter_included(%{query_params: %{"filter_included" => filter_included}} = request)
       when is_binary(filter_included) do
    parse_filter_included(
      put_in(request.query_params["filter_included"], Plug.Conn.Query.decode(filter_included))
    )
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

        related ->
          if AshJsonApi.Resource.Info.derive_filter?(related) do
            path = Enum.map(path, &String.to_existing_atom/1)
            %{request | filter_included: Map.put(request.filter_included, path, filter_statement)}
          else
            add_error(request, "Invalid filter included", request.route.type)
          end
      end
    end)
  end

  defp parse_filter_included(request), do: request

  defp parse_sort_included(%{query_params: %{"sort_included" => sort_included}} = request)
       when is_binary(sort_included) do
    parse_sort_included(
      put_in(request.query_params["sort_included"], Plug.Conn.Query.decode(sort_included))
    )
  end

  defp parse_sort_included(
         %{resource: resource, query_params: %{"sort_included" => sort_included}} = request
       )
       when is_map(sort_included) do
    Enum.reduce(sort_included, request, fn {relationship_path, sort_included}, request ->
      path = String.split(relationship_path)

      case public_related(resource, path) do
        nil ->
          add_error(request, "Invalid sort included", request.route.type)

        related ->
          if AshJsonApi.Resource.Info.derive_sort?(related) do
            path = Enum.map(path, &String.to_existing_atom/1)
            %{request | sort_included: Map.put(request.sort_included, path, sort_included)}
          else
            add_error(request, "Invalid sort included", request.route.type)
          end
      end
    end)
  end

  defp parse_sort_included(request), do: request

  defp parse_fields(%{resource: resource, query_params: %{"fields" => fields}} = request)
       when is_binary(fields) do
    add_fields(request, resource, fields, false)
  end

  defp parse_fields(%{query_params: %{"fields" => fields}} = request) when is_map(fields) do
    Enum.reduce(fields, request, fn {type, fields}, request ->
      # Get all relevant resources better here, i.e using the includes keyword
      # this could miss relationships to things in other apis
      request.domain
      |> Ash.Domain.Info.resources()
      |> Enum.find(&(AshJsonApi.Resource.Info.type(&1) == type))
      |> case do
        nil ->
          request.domain
          |> Spark.otp_app()
          |> case do
            nil ->
              add_error(request, InvalidType.exception(type: type), request.route.type)

            otp_app ->
              otp_app
              |> Application.get_env(:ash_domains, [])
              |> Enum.find_value(fn domain ->
                domain != request.domain &&
                  domain
                  |> Ash.Domain.Info.resources()
                  |> Enum.find(&(AshJsonApi.Resource.Info.type(&1) == type))
              end)
          end

        resource ->
          add_fields(request, resource, fields, true)
      end
    end)
  end

  defp parse_fields(request), do: request

  defp parse_field_inputs(%{query_params: %{"field_inputs" => field_inputs}} = request)
       when is_map(field_inputs) do
    Enum.reduce(field_inputs, request, fn {type, inputs}, request ->
      add_field_inputs(request, type, inputs)
    end)
  end

  defp parse_field_inputs(request), do: request

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

  defp add_field_inputs(request, type, field_inputs) do
    resource =
      request.domain
      |> Ash.Domain.Info.resources()
      |> Enum.find(&(AshJsonApi.Resource.Info.type(&1) == type))

    Enum.reduce(field_inputs, request, fn {calculation_name, arguments}, request ->
      case Ash.Resource.Info.public_calculation(resource, calculation_name) do
        nil ->
          add_error(
            request,
            InvalidField.exception(type: type, parameter?: true, field: calculation_name),
            request.route.type
          )

        calculation ->
          Enum.reduce(arguments, request, fn {arg_name, arg_value}, request ->
            calculation_arg =
              Enum.find(calculation.arguments, fn argument ->
                to_string(argument.name) == arg_name
              end)

            case calculation_arg do
              nil ->
                add_error(
                  request,
                  InvalidField.exception(type: type, parameter?: true, field: arg_name),
                  request.route.type
                )

              _ ->
                cur_resource_field_inputs = Map.get(request.field_inputs, resource, %{})

                cur_calculation_field_inputs =
                  Map.get(cur_resource_field_inputs, calculation.name, %{})

                updated_calculation_field_inputs =
                  Map.put(cur_calculation_field_inputs, calculation_arg.name, arg_value)

                updated_resource_field_inputs =
                  Map.put(
                    cur_resource_field_inputs,
                    calculation.name,
                    updated_calculation_field_inputs
                  )

                updated_field_inputs =
                  Map.put(request.field_inputs, resource, updated_resource_field_inputs)

                %{request | field_inputs: updated_field_inputs}
            end
          end)
      end
    end)
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

        calc = Ash.Resource.Info.public_calculation(resource, key) ->
          fields = Map.update(request.fields, resource, [calc.name], &[calc.name | &1])
          %{request | fields: fields}

        true ->
          add_error(
            request,
            InvalidField.exception(type: type, parameter?: parameter?, field: key),
            request.route.type
          )
      end
    end)
  end

  defp parse_filter(%{query_params: %{"filter" => filter}} = request) when is_binary(filter) do
    parse_filter(put_in(request.query_params["filter"], Plug.Conn.Query.decode(filter)))
  end

  defp parse_filter(%{query_params: %{"filter" => filter}} = request)
       when is_map(filter) do
    if request.action.type == :read && request.route.derive_filter? &&
         AshJsonApi.Resource.Info.derive_filter?(request.resource) do
      %{request | filter: filter}
    else
      %{request | arguments: Map.put(request.arguments, :filter, filter)}
    end
  end

  defp parse_filter(%{query_params: %{"filter" => filter}} = request) do
    if request.action.type == :read && request.route.derive_filter? &&
         AshJsonApi.Resource.Info.derive_filter?(request.resource) do
      add_error(request, "invalid filter", request.route.type)
    else
      %{request | arguments: Map.put(request.arguments, :filter, filter)}
    end
  end

  defp parse_filter(request), do: %{request | filter: %{}}

  defp parse_sort(%{query_params: %{"sort" => sort_string}, resource: resource} = request)
       when is_bitstring(sort_string) do
    if request.action.type == :read && request.route.derive_sort? &&
         AshJsonApi.Resource.Info.derive_sort?(request.resource) do
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

              calc = Ash.Resource.Info.public_calculation(resource, field_name) ->
                %{request | sort: [{calc.name, order} | request.sort]}

              true ->
                add_error(request, "invalid sort #{field}", request.route.type)
            end
          end)
      end
    else
      %{request | arguments: Map.put(request.arguments, :sort, sort_string)}
    end
  end

  defp parse_sort(%{query_params: %{"sort" => sort}} = request) do
    if request.action.type == :read && request.route.derive_sort? &&
         AshJsonApi.Resource.Info.derive_sort?(request.resource) do
      add_error(request, "invalid sort string", request.route.type)
    else
      %{request | arguments: Map.put(request.arguments, :sort, sort)}
    end
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

      %{allowed: _allowed, disallowed: disallowed} ->
        add_error(request, InvalidIncludes.exception(includes: disallowed), request.route.type)
    end
  end

  defp includes_to_keyword(request, includes) do
    includes
    |> Enum.reduce([], fn path, acc ->
      put_path(acc, path)
    end)
    |> set_include_queries(
      request.fields,
      request.field_inputs,
      request.filter_included,
      request.sort_included,
      request.resource
    )
  end

  defp set_include_queries(includes, fields, field_inputs, filters, sorts, resource, path \\ [])

  defp set_include_queries(:linkage_only, _, _, _, _, _, _), do: []

  defp set_include_queries(includes, fields, field_inputs, filters, sorts, resource, path) do
    includes =
      Enum.reduce(
        AshJsonApi.Resource.Info.always_include_linkage(resource),
        includes,
        fn key, includes ->
          if Keyword.has_key?(includes, key) do
            includes
          else
            Keyword.put(includes, key, :linkage_only)
          end
        end
      )

    Enum.map(includes, fn {key, nested} ->
      related = public_related(resource, key)

      nested_queries =
        set_include_queries(nested, fields, field_inputs, filters, sorts, related, path ++ [key])

      related_field_inputs = Map.get(field_inputs, related, %{})

      load =
        fields
        |> Map.get(related)
        |> Kernel.||(
          AshJsonApi.Resource.Info.default_fields(related) ||
            related
            |> Ash.Resource.Info.public_attributes()
            |> Enum.map(& &1.name)
        )
        |> Enum.map(fn field ->
          case Map.get(related_field_inputs, field) do
            nil -> field
            value -> {field, value}
          end
        end)
        |> Kernel.++(nested_queries)

      new_query =
        related
        |> Ash.Query.new()
        |> Ash.Query.load(load)
        |> Map.put(:__linkage_only__, nested == :linkage_only)

      filtered_query =
        case Map.fetch(filters, path ++ [key]) do
          {:ok, filter} ->
            Ash.Query.filter_input(new_query, filter)

          :error ->
            new_query
        end

      sorted_query =
        case Map.fetch(sorts, path ++ [key]) do
          {:ok, sort} ->
            Ash.Query.sort_input(filtered_query, sort)

          :error ->
            filtered_query
        end

      {key, sorted_query}
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

  defp parse_query_params(%{route: route} = request) do
    route.query_params
    |> List.wrap()
    |> Enum.reduce(request, fn query_param, request ->
      case Map.fetch(request.query_params, to_string(query_param)) do
        {:ok, value} -> %{request | arguments: Map.put(request.arguments, query_param, value)}
        :error -> request
      end
    end)
  end

  defp parse_attributes(
         %{route: %{type: :route}, action: action, body: %{"data" => attributes}} = request
       )
       when is_map(attributes) do
    Enum.reduce(attributes, request, fn {key, value}, request ->
      if arg =
           Enum.find(action.arguments, fn argument ->
             to_string(argument.name) == key
           end) do
        %{request | arguments: Map.put(request.arguments || %{}, arg.name, value)}
      else
        request
      end
    end)
  end

  defp parse_attributes(
         %{action: action, body: %{"data" => %{"attributes" => attributes}}} =
           request
       )
       when is_map(attributes) do
    Enum.reduce(attributes, request, fn {key, value}, request ->
      matching_argument = Enum.find(action.arguments, &(to_string(&1.name) == key))
      matching_accept = action |> Map.get(:accept, []) |> Enum.find(&(to_string(&1) == key))

      case {matching_argument || matching_accept, value} do
        {%Ash.Resource.Actions.Argument{name: name, type: Ash.Type.File}, value}
        when is_binary(value) ->
          with {:ok, decoded} <- Base.decode64(value),
               {:ok, device} <- StringIO.open(decoded) do
            file = Ash.Type.File.from_io(device)
            %{request | arguments: Map.put(request.arguments || %{}, name, file)}
          else
            :error ->
              add_error(
                request,
                AshJsonApi.Error.InvalidField.exception(
                  type: Ash.Type.File,
                  field: name,
                  detail: "valid base64 expected"
                ),
                request.route.type
              )
          end

        {%Ash.Resource.Actions.Argument{name: name}, value} ->
          %{request | arguments: Map.put(request.arguments || %{}, name, value)}

        {accept, value} when is_atom(accept) ->
          %{request | attributes: Map.put(request.attributes || %{}, accept, value)}

        {nil, _value} ->
          request
      end
    end)
  end

  defp parse_attributes(request), do: %{request | attributes: %{}, arguments: %{}}

  defp parse_action_arguments(%{action: %{type: :read} = action} = request) do
    action.arguments
    |> Enum.filter(& &1.public?)
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

  defp parse_action_arguments(%{action: %{type: :action} = action} = request) do
    action.arguments
    |> Enum.filter(& &1.public?)
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

  defp parse_action_arguments(request), do: request

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
           {:arg, arg} when not is_nil(arg) <-
             {:arg,
              Enum.find(
                action.arguments,
                &(to_string(&1.name) == name &&
                    has_relationship_argument?(relationship_arguments, &1.name))
              )},
           {:ok, change_value} <-
             relationship_change_value(name, data) do
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
        {:arg, nil} ->
          add_error(
            request,
            Ash.Error.Invalid.NoSuchInput.exception(input: name, resource: request.resource),
            request.route.type
          )

        {:error, error} ->
          add_error(
            request,
            error,
            request.route.type
          )

        %{"data" => data} ->
          add_error(
            request,
            InvalidRelationshipInput.exception(relationship: name, input: data),
            request.route.type
          )

        other ->
          add_error(
            request,
            InvalidRelationshipInput.exception(relationship: name, input: other),
            request.route.type
          )
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

  defp relationship_change_value(name, value)
       when is_list(value) do
    value
    |> Stream.map(&relationship_change_value(name, &1))
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, change}, {:ok, changes} ->
        {:cont, {:ok, [change | changes]}}

      {:error, change}, _ ->
        {:halt, {:error, change}}
    end)
    |> case do
      {:ok, changes} ->
        {:ok, Enum.reverse(changes)}

      {:error, input} ->
        {:error, InvalidRelationshipInput.exception(relationship: name, input: input)}
    end
  end

  defp relationship_change_value(_name, %{"id" => id} = value) do
    case Map.fetch(value, "meta") do
      {:ok, meta} -> {:ok, Map.put(meta, "id", id)}
      _ -> {:ok, %{"id" => id}}
    end
  end

  defp relationship_change_value(_name, value) when is_nil(value) do
    {:ok, value}
  end

  defp relationship_change_value(_name, %{"meta" => meta}) when is_map(meta) do
    {:ok, meta}
  end

  defp relationship_change_value(name, value) do
    {:error, InvalidRelationshipInput.exception(relationship: name, input: value)}
  end

  defp url(conn) do
    Conn.request_url(conn)
  end
end
