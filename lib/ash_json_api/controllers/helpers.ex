# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.Helpers do
  @moduledoc false
  require Logger
  alias AshJsonApi.Controllers.Response
  alias AshJsonApi.{Error, Request}
  alias AshJsonApi.Includes.Includer

  require Ash.Query

  def render_or_render_errors(request, conn, function) do
    chain(request, fn request ->
      conn =
        if request.route.modify_conn do
          request.route.modify_conn.(
            conn,
            AshJsonApi.Controllers.Helpers.subject(request),
            request.assigns.result,
            request
          )
        else
          conn
        end

      Request.assign(request, :conn, conn)
    end)
    |> chain(fn request -> function.(request.assigns[:conn], request) end,
      fallback: fn request ->
        Response.render_errors(request.assigns[:conn] || conn, request)
      end
    )
  end

  def fetch_includes(request) do
    chain(request, fn request ->
      {new_result, includes} = Includer.get_includes(request.assigns.result, request)

      request
      |> Request.assign(:result, new_result)
      |> Request.assign(:includes, includes)
    end)
  end

  def fetch_records(request) do
    chain(request, fn request ->
      if request.action.type == :action do
        action_input =
          request.resource
          |> Ash.ActionInput.new()
          |> Ash.ActionInput.set_context(request.context || %{})
          |> Ash.ActionInput.for_action(
            request.action.name,
            request.arguments,
            Request.opts(request)
          )

        request = Request.assign(request, :action_input, action_input)

        with {:ok, result} <- Ash.run_action(action_input),
             {:ok, result} <- load_action_data(result, request) do
          Request.assign(request, :result, result)
        else
          {:error, error} ->
            Request.add_error(request, error, :read)
        end
      else
        filter =
          case request.filter do
            empty when empty in [%{}, nil] ->
              nil

            other ->
              other
          end

        query =
          request.resource
          |> Ash.Query.load(request.includes_keyword)
          |> Ash.Query.set_context(request.context)
          |> Ash.Query.do_filter(filter)
          |> Ash.Query.sort(request.sort)
          |> Ash.Query.load(fields(request, request.resource))
          |> Ash.Query.for_read(request.action.name, request.arguments, Request.opts(request))

        request = Request.assign(request, :query, query)

        query
        |> Ash.read(Request.opts(request))
        |> case do
          {:ok, result} ->
            Request.assign(request, :result, result)

          {:error, error} ->
            Request.add_error(request, error, :read)
        end
      end
    end)
  end

  defp load_action_data(result, request) do
    # If the resouce has no primary read action, we can skip loading
    if is_nil(Ash.Resource.Info.primary_action(request.resource, :read)) do
      {:ok, result}
    else
      with {:ok, result} <-
             Ash.load(
               result,
               fields(
                 request,
                 request.resource
               ),
               Request.load_opts(request, reuse_values?: true)
             ),
           {:ok, result} <-
             Ash.load(result, request.includes_keyword, Request.load_opts(request)) do
        {:ok, result}
      else
        {:error, error} ->
          {:error, error}
      end
    end
  end

  def run_action(request) do
    chain(request, fn request ->
      case path_args_and_filter(
             request.path_params,
             request.resource,
             request.action,
             request.route
           ) do
        {:ok, route_params, _filter} ->
          action_input =
            request.resource
            |> Ash.ActionInput.new()
            |> Ash.ActionInput.set_context(request.context || %{})
            |> Ash.ActionInput.for_action(
              request.action.name,
              Map.merge(request.arguments, route_params),
              Request.opts(request)
            )

          request = Request.assign(request, :action_input, action_input)

          case Ash.run_action(action_input) do
            :ok ->
              Request.assign(request, :result, :ok)

            {:ok, result} ->
              Request.assign(request, :result, result)

            {:error, error} ->
              Request.add_error(request, error, :action)
          end

        {:error, error} ->
          Request.add_error(request, error, :action)
      end
    end)
  end

  def fetch_metadata(request) do
    chain(request, fn request ->
      if is_function(request.route.metadata, 3) do
        subject = subject(request)

        metadata = request.route.metadata.(subject, request.assigns.result, request)
        Request.assign(request, :metadata, metadata)
      else
        Request.assign(request, :metadata, %{})
      end
    end)
  end

  def subject(request) do
    Map.get(
      request.assigns,
      :query,
      Map.get(request.assigns, :changeset, Map.get(request.assigns, :action_input))
    )
  end

  def create_record(request) do
    chain(request, fn %{resource: resource} = request ->
      cond do
        request.action.type == :read ->
          case path_args_and_filter(
                 request.path_params,
                 request.resource,
                 request.action,
                 request.route
               ) do
            {:ok, route_params, _filter} ->
              query =
                request.resource
                |> Ash.Query.load(
                  fields(request, request.resource) ++ (request.includes_keyword || [])
                )
                |> Ash.Query.set_context(request.context || %{})
                |> Ash.Query.for_read(
                  request.action.name,
                  Map.merge(Map.merge(request.attributes, request.arguments), route_params),
                  Request.opts(request)
                )

              request = Request.assign(request, :query, query)

              case Ash.read(query) do
                {:ok, %resource{} = result} when resource == request.resource ->
                  Request.assign(request, :result, result)

                {:ok, [result]} ->
                  Request.assign(request, :result, result)

                {:ok, %page{results: [result]}} when page in [Ash.Page.Keyset, Ash.Page.Offset] ->
                  Request.assign(request, :result, result)

                {:ok, []} ->
                  Request.add_error(request, Ash.Error.Query.NotFound.exception(), :create)

                {:ok, %page{results: []}} when page in [Ash.Page.Keyset, Ash.Page.Offset] ->
                  Request.add_error(request, Ash.Error.Query.NotFound.exception(), :create)

                {:ok, [result | _]} ->
                  Logger.warning(
                    "Got multiple results for #{inspect(request.resource)}.#{request.action} in `:post` handler. Expected zero or one. Extra results are being ignored."
                  )

                  Request.assign(request, :result, result)

                {:ok, %page{results: [result | _]}}
                when page in [Ash.Page.Keyset, Ash.Page.Offset] ->
                  Request.assign(request, :result, result)

                  Logger.warning(
                    "Got multiple results for #{inspect(request.resource)}.#{request.action} in `:post` handler. Expected zero or one. Extra results are being ignored."
                  )

                {:error, error} ->
                  Request.add_error(request, error, :create)
              end

            {:error, error} ->
              Request.add_error(request, error, :create)
          end

        request.action.type == :action ->
          case path_args_and_filter(
                 request.path_params,
                 request.resource,
                 request.action,
                 request.route
               ) do
            {:ok, route_params, _filter} ->
              action_input =
                request.resource
                |> Ash.ActionInput.new()
                |> Ash.ActionInput.set_context(request.context || %{})
                |> Ash.ActionInput.for_action(
                  request.action.name,
                  Map.merge(Map.merge(request.attributes, request.arguments), route_params),
                  Request.opts(request)
                )

              request = Request.assign(request, :action_input, action_input)

              with {:ok, result} <- Ash.run_action(action_input),
                   {:ok, result} <-
                     Ash.load(
                       result,
                       fields(request, request.resource),
                       Request.load_opts(request, reuse_values?: true)
                     ),
                   {:ok, result} <-
                     Ash.load(
                       result,
                       request.includes_keyword || [],
                       Request.load_opts(request)
                     ) do
                Request.assign(request, :result, result)
              else
                {:error, error} ->
                  Request.add_error(request, error, :create)
              end

            {:error, error} ->
              Request.add_error(request, error, :create)
          end

        true ->
          opts =
            if request.route.upsert? do
              if request.route.upsert_identity do
                [
                  upsert?: true,
                  upsert_identity: request.route.upsert_identity
                ]
              else
                [
                  upsert?: true
                ]
              end
            else
              []
            end

          case path_args_and_filter(
                 request.path_params,
                 request.resource,
                 request.action,
                 request.route
               ) do
            {:ok, route_params, _filter} ->
              changeset =
                resource
                |> Ash.Changeset.new()
                |> Ash.Changeset.set_context(request.context)
                |> Ash.Changeset.for_create(
                  request.action.name,
                  Map.merge(Map.merge(request.attributes, request.arguments), route_params),
                  Request.opts(request)
                )
                |> Ash.Changeset.load(
                  fields(request, request.resource) ++ (request.includes_keyword || [])
                )

              request = Request.assign(request, :changeset, changeset)

              changeset
              |> Ash.create(Request.opts(request, opts))
              |> case do
                {:ok, record} ->
                  Request.assign(request, :result, record)

                {:error, error} ->
                  Request.add_error(request, error, :create)
              end

            {:error, error} ->
              Request.add_error(request, error, :create)
          end
      end
    end)
  end

  def update_record(request, attributes \\ &Map.merge(&1.attributes, &1.arguments)) do
    chain(request, fn request ->
      if request.action.type == :action do
        case path_args_and_filter(
               request.path_params,
               request.resource,
               request.action,
               request.route
             ) do
          {:ok, route_params, _filter} ->
            action_input =
              request.resource
              |> Ash.ActionInput.new()
              |> Ash.ActionInput.set_context(request.context || %{})
              |> Ash.ActionInput.for_action(
                request.action.name,
                Map.merge(attributes.(request), route_params),
                Request.opts(request)
              )

            request = Request.assign(request, :action_input, action_input)

            with {:ok, result} <- Ash.run_action(action_input),
                 {:ok, result} <-
                   Ash.load(
                     result,
                     fields(request, request.resource),
                     Request.load_opts(request, reuse_values?: true)
                   ),
                 {:ok, result} <-
                   Ash.load(
                     result,
                     request.includes_keyword || [],
                     Request.load_opts(request)
                   ) do
              Request.assign(request, :result, result)
            else
              {:error, error} ->
                Request.add_error(request, error, :create)
            end

          {:error, error} ->
            Request.add_error(request, error, :create)
        end
      else
        request
        |> fetch_query()
        |> case do
          {:error, error} ->
            Request.add_error(request, error, :fetch_from_path)

          {:ok, filter, query} ->
            request = Request.assign(request, :query, query)

            query
            |> Ash.bulk_update(
              request.action.name,
              attributes.(request),
              Request.opts(request,
                authorize_changeset_with: Request.authorize_bulk_with(query.resource),
                return_errors?: true,
                notify?: true,
                strategy: [:atomic, :stream, :atomic_batches],
                allow_stream_with: :full_read,
                return_records?: true,
                context: request.context || %{},
                load: fields(request, request.resource) ++ (request.includes_keyword || [])
              )
            )
            |> case do
              %Ash.BulkResult{status: :success, records: [result | _]} ->
                request
                |> Request.assign(:result, result)
                |> Request.assign(:record_from_path, result)

              %Ash.BulkResult{status: :success, records: []} ->
                error = Error.NotFound.exception(filter: filter, resource: request.resource)
                Request.add_error(request, error, :fetch_from_path)

              %Ash.BulkResult{status: :error, errors: errors} ->
                Request.add_error(request, errors, :update)
            end
        end
      end
    end)
  end

  def add_to_relationship(request, relationship_name) do
    chain(request, fn %{assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name
      values = normalize_relationship_identifiers(request)

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, values, type: :append)
      |> Ash.Changeset.set_context(request.context)
      |> Ash.Changeset.for_update(action, %{}, Request.opts(request))
      |> Ash.Changeset.load(fields(request, request.resource))
      |> Ash.update(Request.opts(request))
      |> case do
        {:ok, updated} ->
          request
          |> Request.assign(:result, Map.get(updated, relationship_name))

        {:error, error} ->
          Request.add_error(request, error, :add_to_relationship)
      end
    end)
  end

  def replace_relationship(request, relationship_name) do
    chain(request, fn %{assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name
      values = normalize_relationship_identifiers(request)

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, values, type: :append_and_remove)
      |> Ash.Changeset.set_context(request.context)
      |> Ash.Changeset.for_update(action, %{}, Request.opts(request))
      |> Ash.Changeset.load(fields(request, request.resource))
      |> Ash.update(Request.opts(request))
      |> case do
        {:ok, updated} ->
          request
          |> Request.assign(:result, Map.get(updated, relationship_name))

        {:error, error} ->
          Request.add_error(request, error, :replace_relationship)
      end
    end)
  end

  def delete_from_relationship(request, relationship_name) do
    chain(request, fn %{assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name
      values = normalize_relationship_identifiers(request)

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, values, type: :remove)
      |> Ash.Changeset.set_context(request.context)
      |> Ash.Changeset.for_update(action, %{}, Request.opts(request))
      |> Ash.update(Request.opts(request))
      |> case do
        {:ok, record} ->
          record
          |> Ash.load(fields(request, request.resource), Request.load_opts(request))
          |> case do
            {:ok, updated} ->
              request
              |> Request.assign(:result, Map.get(updated, relationship_name))

            {:error, error} ->
              Request.add_error(request, error, :delete_from_relationship)
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  def destroy_record(request) do
    chain(request, fn request ->
      if request.action.type == :action do
        case path_args_and_filter(
               request.path_params,
               request.resource,
               request.action,
               request.route
             ) do
          {:ok, route_params, _filter} ->
            action_input =
              request.resource
              |> Ash.ActionInput.new()
              |> Ash.ActionInput.set_context(request.context || %{})
              |> Ash.ActionInput.for_action(
                request.action.name,
                route_params,
                Request.opts(request)
              )

            request = Request.assign(request, :action_input, action_input)

            with {:ok, result} <- Ash.run_action(action_input),
                 {:ok, result} <-
                   Ash.load(
                     result,
                     fields(request, request.resource),
                     Request.load_opts(request, reuse_values?: true)
                   ),
                 {:ok, result} <-
                   Ash.load(
                     result,
                     request.includes_keyword || [],
                     Request.load_opts(request)
                   ) do
              Request.assign(request, :result, result)
            else
              {:error, error} ->
                Request.add_error(request, error, :create)
            end

          {:error, error} ->
            Request.add_error(request, error, :create)
        end
      else
        request
        |> fetch_query()
        |> case do
          {:error, error} ->
            Request.add_error(request, error, :fetch_from_path)

          {:ok, filter, query} ->
            request = Request.assign(request, :query, query)

            query
            |> Ash.bulk_destroy(
              request.action.name,
              %{},
              Request.opts(request,
                return_errors?: true,
                authorize_changeset_with: Request.authorize_bulk_with(query.resource),
                notify?: true,
                strategy: [:atomic, :stream, :atomic_batches],
                allow_stream_with: :full_read,
                return_records?: true,
                context: request.context || %{},
                load: fields(request, request.resource) ++ (request.includes_keyword || [])
              )
            )
            |> case do
              %Ash.BulkResult{status: :success, records: [result | _]} ->
                request
                |> Request.assign(:result, result)
                |> Request.assign(:record_from_path, result)

              %Ash.BulkResult{status: :success, records: []} ->
                error = Error.NotFound.exception(filter: filter, resource: request.resource)
                Request.add_error(request, error, :fetch_from_path)

              %Ash.BulkResult{status: :error, errors: errors} ->
                Request.add_error(request, errors, :update)
            end
        end
      end
    end)
  end

  defp path_args_and_filter(path_params, resource, action, route) do
    primary_key_fields = AshJsonApi.Resource.Info.primary_key_fields(resource)

    Enum.reduce_while(path_params, {:ok, %{}, %{}}, fn
      {key, value}, {:ok, params, filter} ->
        # Check if this parameter should be parsed as a composite key
        if route != nil and to_string(route.path_param_is_composite_key) == key and
             primary_key_fields != [] do
          primary_key_delimiter = AshJsonApi.Resource.Info.primary_key_delimiter(resource)
          values = String.split(value, primary_key_delimiter)

          if Enum.count(values) != Enum.count(primary_key_fields) do
            {:halt,
             {:error, Ash.Error.Query.NotFound.exception(primary_key: value, resource: resource)}}
          else
            filter =
              primary_key_fields
              |> Enum.zip(values)
              |> Enum.reduce(filter, fn {key, value}, filter ->
                Map.put(filter, key, value)
              end)

            {:cont, {:ok, params, filter}}
          end
        else
          # Normal parameter handling
          case Enum.find(action.arguments, &(to_string(&1.name) == key)) do
            nil ->
              case Ash.Resource.Info.attribute(resource, key) do
                nil ->
                  {:halt,
                   {:error,
                    Ash.Error.Invalid.NoSuchInput.exception(
                      resource: resource,
                      action: action.name,
                      input: key,
                      inputs: []
                    )}}

                attribute ->
                  {:cont, {:ok, params, Map.put(filter, attribute.name, value)}}
              end

            argument ->
              {:cont, {:ok, Map.put(params, argument.name, value), filter}}
          end
        end
    end)
  end

  def fetch_query(%{resource: request_resource} = request, through_resource \\ nil, load \\ nil) do
    resource = through_resource || request_resource

    action =
      if through_resource || request.action.type != :read do
        if request.route.read_action do
          Ash.Resource.Info.action(request.resource, request.route.read_action)
        else
          Ash.Resource.Info.primary_action!(resource, :read)
        end
      else
        request.action
      end

    case path_args_and_filter(request.path_params, resource, action, request.route) do
      {:error, error} ->
        {:error, error}

      {:ok, params, filter} ->
        action = action.name

        fields_to_load =
          if through_resource do
            []
          else
            fields(request, request.resource)
          end

        query =
          if filter do
            case Ash.Filter.parse_input(resource, filter) do
              {:ok, parsed} ->
                {:ok, Ash.Query.filter(resource, ^parsed)}

              {:error, error} ->
                {:error, error}
            end
          else
            {:ok, resource}
          end

        case query do
          {:error, error} ->
            {:error, Request.add_error(request, error, :filter)}

          {:ok, query} ->
            query =
              if load do
                Ash.Query.load(query, load)
              else
                query
              end

            {:ok, filter,
             query
             |> Ash.Query.load(fields_to_load ++ (request.includes_keyword || []))
             |> Ash.Query.set_context(request.context)
             |> Ash.Query.for_read(
               action,
               params,
               Keyword.put(Request.opts(request), :page, false)
             )
             |> Ash.Query.limit(1)}
        end
    end
  end

  def fetch_record_from_path(request, through_resource \\ nil, load \\ nil) do
    chain(request, fn %{resource: request_resource} = request ->
      resource = through_resource || request_resource

      action =
        if request.route.type != :get && (through_resource || request.action.type != :read) do
          if request.route.read_action do
            Ash.Resource.Info.action(request.resource, request.route.read_action)
          else
            Ash.Resource.Info.primary_action!(resource, :read)
          end
        else
          request.action
        end

      if action.type == :action do
        action_input =
          request.resource
          |> Ash.ActionInput.new()
          |> Ash.ActionInput.set_context(request.context || %{})
          |> Ash.ActionInput.for_action(
            request.action.name,
            request.arguments,
            Request.opts(request)
          )

        request = Request.assign(request, :action_input, action_input)

        {load_lazy, load} =
          if through_resource do
            {[], []}
          else
            {fields(request, request.resource), request.includes_keyword || []}
          end

        with {:ok, result} <- Ash.run_action(action_input),
             {:ok, result} <-
               Ash.load(result, load_lazy, Request.load_opts(request, reuse_values?: true)),
             {:ok, result} <-
               Ash.load(result, load, Request.load_opts(request)) do
          request
          |> Request.assign(:result, result)
          |> Request.assign(:record_from_path, result)
        else
          {:error, error} ->
            Request.add_error(request, error, :read)
        end
      else
        case path_args_and_filter(request.path_params, resource, action, request.route) do
          {:ok, params, filter} ->
            action = action.name

            fields_to_load =
              if through_resource do
                []
              else
                fields(request, request.resource) ++ (request.includes_keyword || [])
              end

            query =
              if filter do
                case Ash.Filter.parse_input(resource, filter) do
                  {:ok, parsed} ->
                    {:ok, Ash.Query.filter(resource, ^parsed)}

                  {:error, error} ->
                    {:error, error}
                end
              else
                {:ok, resource}
              end

            case query do
              {:error, error} ->
                {:error, Request.add_error(request, error, :filter)}

              {:ok, query} ->
                query =
                  if load do
                    Ash.Query.load(query, load)
                  else
                    query
                  end

                query =
                  query
                  |> Ash.Query.set_context(request.context)
                  |> Ash.Query.for_read(
                    action,
                    Map.merge(request.arguments, params),
                    Keyword.put(Request.opts(request), :page, false)
                  )
                  |> Ash.Query.load(fields_to_load)

                request = Request.assign(request, :query, query)

                query
                |> Ash.read_one(Request.opts(request))
                |> case do
                  {:ok, nil} ->
                    error = Error.NotFound.exception(filter: filter, resource: resource)
                    Request.add_error(request, error, :fetch_from_path)

                  {:ok, record} ->
                    request
                    |> Request.assign(:result, record)
                    |> Request.assign(:record_from_path, record)

                  {:error, error} ->
                    Request.add_error(request, error, :fetch_from_path)
                end
            end

          {:error, error} ->
            Request.add_error(request, error, :fetch_from_path)
        end
      end
    end)
  end

  def fetch_related(request, through_resource \\ nil) do
    relationship =
      Ash.Resource.Info.public_relationship(
        through_resource || request.resource,
        request.relationship
      )

    sort = request.sort || default_sort(request.resource)

    load_params =
      if Map.get(request.assigns, :page) do
        [page: request.assigns.page]
      else
        []
      end

    destination_query =
      relationship.destination
      |> Ash.Query.new()
      |> Ash.Query.filter(^request.filter)
      |> Ash.Query.sort(sort)
      |> Ash.Query.load(request.includes_keyword)
      |> Ash.Query.load(fields(request, request.resource))
      |> Ash.Query.set_context(request.context)
      |> Ash.Query.put_context(:override_domain_params, load_params)

    request = Request.assign(request, :query, destination_query)

    request
    |> fetch_record_from_path(through_resource, [{relationship.name, destination_query}])
    |> chain(fn %{
                  assigns: %{result: record},
                  relationship: relationship
                } = request ->
      paginated_result =
        record
        |> Map.get(relationship)
        |> paginator_or_list()

      request
      |> Request.assign(:result, paginated_result)
    end)
  end

  defp paginator_or_list(result) do
    case result do
      %{results: _} = paginator ->
        paginator

      other ->
        List.wrap(other)
    end
  end

  defp fields(request, resource) do
    fields =
      Map.get(request.fields, resource) || request.route.default_fields ||
        AshJsonApi.Resource.Info.default_fields(resource) ||
        Enum.map(Ash.Resource.Info.public_attributes(resource), & &1.name)

    field_inputs = request.field_inputs[resource] || %{}

    Enum.map(fields, fn field ->
      case Map.get(field_inputs, field) do
        nil -> field
        value -> {field, value}
      end
    end)
  end

  defp default_sort(resource) do
    created_at =
      Ash.Resource.Info.public_attribute(resource, :created_at) ||
        Ash.Resource.Info.public_attribute(resource, :inserted_at)

    if created_at do
      [{created_at.name, :asc}]
    else
      Ash.Resource.Info.primary_key(resource)
    end
  end

  def fetch_id_path_param(request) do
    chain(request, fn request ->
      case request.path_params do
        %{"id" => id} ->
          Request.assign(request, :id, id)

        _ ->
          Request.add_error(
            request,
            AshJsonApi.Error.InvalidPathParam.exception(parameter: "id", url: request.url),
            :id_path_param
          )
      end
    end)
  end

  # This doesn't need to use chain, because its stateless and safe to
  # do anytime. Returning multiple errors is a nice feature of JSON API
  def fetch_pagination_parameters(request) do
    if request.action.type == :read do
      request
      |> add_pagination_parameter(:limit, :integer)
      |> add_pagination_parameter(:offset, :integer)
      |> add_pagination_parameter(:after, :string)
      |> add_pagination_parameter(:before, :string)
      |> add_pagination_parameter(:count, :boolean)
    else
      request
    end
  end

  defp add_pagination_parameter(request, parameter, type) do
    with %{"page" => page} <- request.query_params,
         {:ok, value} <- Map.fetch(page, to_string(parameter)) do
      case cast_pagination_parameter(value, type) do
        {:ok, value} ->
          Request.update_assign(
            request,
            :page,
            [{parameter, value}],
            &Keyword.put(&1, parameter, value)
          )

        :error ->
          Request.add_error(
            request,
            Error.InvalidPagination.exception(source_parameter: "page[#{parameter}]"),
            :read
          )
      end
    else
      _ ->
        request
    end
  end

  defp cast_pagination_parameter(value, :integer) do
    case Integer.parse(value) do
      {integer, ""} ->
        {:ok, integer}

      _ ->
        :error
    end
  end

  defp cast_pagination_parameter("true", :boolean), do: {:ok, true}
  defp cast_pagination_parameter("false", :boolean), do: {:ok, false}
  defp cast_pagination_parameter(_, :boolean), do: :error

  defp cast_pagination_parameter(value, :string) when is_binary(value) do
    {:ok, value}
  end

  defp cast_pagination_parameter(_, _), do: :error

  def chain(request, func, opts \\ []) do
    case request.errors do
      [] ->
        func.(request)

      _ ->
        case Keyword.fetch(opts, :fallback) do
          {:ok, fallback} ->
            fallback.(request)

          _ ->
            request
        end
    end
  end

  def resource_identifiers(request, argument) do
    identifiers =
      if map_type?(argument.type) do
        request.resource_identifiers
      else
        Enum.map(request.resource_identifiers, fn
          %{:id => id} -> id
          {%{:id => id}, _meta} -> id
        end)
      end

    case argument.type do
      {:array, _} ->
        %{argument.name => identifiers}

      _ ->
        %{argument.name => Enum.at(identifiers, 0)}
    end
  end

  defp map_type?(type) do
    case type do
      :map -> true
      Ash.Type.Map -> true
      Ash.Type.Struct -> true
      :struct -> true
      type -> Ash.Type.embedded_type?(type)
    end
  end

  defp normalize_relationship_identifiers(request) do
    case request.resource_identifiers do
      nil ->
        nil

      list when is_list(list) ->
        Enum.map(list, fn
          {%{id: id}, _meta} -> id
          %{id: id} -> id
        end)

      %{id: id} ->
        id
    end
  end
end
