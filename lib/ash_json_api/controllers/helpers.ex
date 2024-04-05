defmodule AshJsonApi.Controllers.Helpers do
  @moduledoc false
  # @moduledoc """
  # When we open up ash json api tooling to allow people to build custom
  # behavior around it, we can use this documentation
  # Tools for control flow around a request, and common controller utilities.

  # While we haven't focused on supporting it yet, this will eventually be a set of tools
  # that can be used to build custom controller actions, without having to write everything
  # yourself.

  # `chain/2` lets us pipe cleanly, only doing stateful things if no errors
  # have been generated yet.
  # """
  alias AshJsonApi.Controllers.Response
  alias AshJsonApi.{Error, Request}
  alias AshJsonApi.Includes.Includer

  require Ash.Query

  def render_or_render_errors(request, conn, function) do
    chain(request, function,
      fallback: fn request ->
        Response.render_errors(conn, request)
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
      filter =
        case request.filter do
          empty when empty in [%{}, nil] ->
            nil

          other ->
            other
        end

      request.resource
      |> Ash.Query.load(request.includes_keyword)
      |> Ash.Query.set_context(request.context)
      |> Ash.Query.do_filter(filter)
      |> Ash.Query.sort(request.sort)
      |> Ash.Query.load(fields(request, request.resource))
      |> Ash.Query.for_read(request.action.name, request.arguments, Request.opts(request))
      |> Ash.read(Request.opts(request))
      |> case do
        {:ok, result} ->
          Request.assign(request, :result, result)

        {:error, error} ->
          Request.add_error(request, error, :read)
      end
    end)
  end

  def create_record(request) do
    chain(request, fn %{resource: resource} = request ->
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

      resource
      |> Ash.Changeset.for_create(
        request.action.name,
        Map.merge(request.attributes, request.arguments),
        Request.opts(request)
      )
      |> Ash.Changeset.set_context(request.context)
      |> Ash.Changeset.load(fields(request, request.resource) ++ (request.includes_keyword || []))
      |> Ash.create(Request.opts(request, opts))
      |> case do
        {:ok, record} ->
          Request.assign(request, :result, record)

        {:error, error} ->
          Request.add_error(request, error, :create)
      end
    end)
  end

  def update_record(request, attributes \\ &Map.merge(&1.attributes, &1.arguments)) do
    chain(request, fn %{assigns: %{result: result}} ->
      result
      |> Ash.Changeset.for_update(
        request.action.name,
        attributes.(request),
        Request.opts(request)
      )
      |> Ash.Changeset.set_context(request.context)
      |> Ash.Changeset.load(fields(request, request.resource) ++ (request.includes_keyword || []))
      |> Ash.update(Request.opts(request))
      |> case do
        {:ok, record} ->
          Request.assign(request, :result, record)

        {:error, error} ->
          Request.add_error(request, error, :update)
      end
    end)
  end

  def add_to_relationship(request, relationship_name) do
    chain(request, fn %{assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, request.resource_identifiers,
        type: :append
      )
      |> Ash.Changeset.for_update(action, %{}, Request.opts(request))
      |> Ash.Changeset.set_context(request.context)
      |> Ash.Changeset.load(fields(request, request.resource))
      |> Ash.update(Request.opts(request))
      |> case do
        {:ok, updated} ->
          request
          |> Request.assign(:record_from_path, updated)
          |> Request.assign(:result, Map.get(updated, relationship_name))

        {:error, error} ->
          Request.add_error(request, error, :add_to_relationship)
      end
    end)
  end

  def replace_relationship(request, relationship_name) do
    chain(request, fn %{assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, request.resource_identifiers,
        type: :append_and_remove
      )
      |> Ash.Changeset.for_update(action, %{}, Request.opts(request))
      |> Ash.Changeset.set_context(request.context)
      |> Ash.Changeset.load(fields(request, request.resource))
      |> Ash.update(Request.opts(request))
      |> case do
        {:ok, updated} ->
          request
          |> Request.assign(:record_from_path, updated)
          |> Request.assign(:result, Map.get(updated, relationship_name))

        {:error, error} ->
          Request.add_error(request, error, :replace_relationship)
      end
    end)
  end

  def delete_from_relationship(request, relationship_name) do
    chain(request, fn %{assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, request.resource_identifiers,
        type: :remove
      )
      |> Ash.Changeset.for_update(action, Request.opts(request))
      |> Ash.Changeset.set_context(request.context)
      |> Ash.update(Request.opts(request))
      |> Ash.load(fields(request, request.resource), Request.opts(request))
      |> case do
        {:ok, updated} ->
          request
          |> Request.assign(:record_from_path, updated)
          |> Request.assign(:result, Map.get(updated, relationship_name))

        {:error, error} ->
          Request.add_error(request, error, :delete_from_relationship)
      end
    end)
  end

  def destroy_record(request) do
    chain(request, fn %{assigns: %{result: result}} = request ->
      result
      |> Ash.Changeset.for_destroy(request.action.name, %{}, Request.opts(request))
      |> Ash.Changeset.set_context(request.context)
      |> Ash.destroy(Request.opts(request))
      |> case do
        :ok ->
          Request.assign(request, :result, nil)

        {:error, error} ->
          Request.add_error(request, error, :destroy)
      end
    end)
  end

  defp path_args_and_filter(path_params, resource, action) do
    Enum.reduce(path_params, {%{}, %{}}, fn {key, value}, {params, filter} ->
      case Enum.find(action.arguments, &(to_string(&1.name) == key)) do
        nil ->
          case Ash.Resource.Info.public_attribute(resource, key) do
            nil ->
              {params, filter}

            attribute ->
              {params, Map.put(filter, attribute.name, value)}
          end

        argument ->
          {Map.put(params, argument.name, value), filter}
      end
    end)
  end

  def fetch_record_from_path(request, through_resource \\ nil, load \\ nil) do
    chain(request, fn %{resource: request_resource} = request ->
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

      {params, filter} = path_args_and_filter(request.path_params, resource, action)

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

          query
          |> Ash.Query.load(fields_to_load ++ (request.includes_keyword || []))
          |> Ash.Query.set_context(request.context)
          |> Ash.Query.for_read(
            action,
            Map.merge(request.arguments, params),
            Keyword.put(Request.opts(request), :page, false)
          )
          |> Ash.read_one(Request.opts(request))
          |> case do
            {:ok, nil} ->
              error = Error.NotFound.exception(filter: filter, resource: resource)
              Request.add_error(request, error, :fetch_from_path)

              Request.add_error(request, error, :fetch_from_path)

            {:ok, record} ->
              request
              |> Request.assign(:result, record)
              |> Request.assign(:record_from_path, record)

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
      |> Request.assign(:record_from_path, record)
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
    Map.get(request.fields, resource) || request.route.default_fields || []
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
            "id path parameter not present in get route: #{request.url}",
            :id_path_param
          )
      end
    end)
  end

  # This doesn't need to use chain, because its stateless and safe to
  # do anytime. Returning multiple errors is a nice feature of JSON API
  def fetch_pagination_parameters(request) do
    request
    |> add_pagination_parameter(:limit, :integer)
    |> add_pagination_parameter(:offset, :integer)
    |> add_pagination_parameter(:after, :string)
    |> add_pagination_parameter(:before, :string)
    |> add_pagination_parameter(:count, :boolean)
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
        Enum.map(request.resource_identifiers, fn identifier ->
          identifier["id"]
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
      type -> Ash.Type.embedded_type?(type)
    end
  end
end
