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
      |> Ash.Query.do_filter(filter)
      |> Ash.Query.sort(request.sort)
      |> Ash.Query.load(fields(request, request.resource))
      |> Ash.Query.for_read(request.action.name, request.arguments, Request.opts(request))
      |> request.api.read()
      |> case do
        {:ok, result} ->
          Request.assign(request, :result, result)

        {:error, error} ->
          Request.add_error(request, error, :read)
      end
    end)
  end

  def create_record(request) do
    chain(request, fn %{api: api, resource: resource} = request ->
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
      |> api.create(opts)
      |> api.load(fields(request, request.resource) ++ (request.includes_keyword || []))
      |> case do
        {:ok, record} ->
          Request.assign(request, :result, record)

        {:error, error} ->
          Request.add_error(request, error, :create)
      end
    end)
  end

  def update_record(request) do
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      result
      |> Ash.Changeset.for_update(
        request.action.name,
        Map.merge(request.attributes, request.arguments),
        Request.opts(request)
      )
      |> api.update()
      |> api.load(fields(request, request.resource) ++ (request.includes_keyword || []))
      |> case do
        {:ok, record} ->
          Request.assign(request, :result, record)

        {:error, error} ->
          Request.add_error(request, error, :update)
      end
    end)
  end

  def add_to_relationship(request, relationship_name) do
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, request.resource_identifiers,
        type: :append
      )
      |> Ash.Changeset.for_update(action, %{}, Request.opts(request))
      |> api.update()
      |> api.load(fields(request, request.resource))
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
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, request.resource_identifiers,
        type: :append_and_remove
      )
      |> Ash.Changeset.for_update(action, %{}, Request.opts(request))
      |> api.update()
      |> api.load(fields(request, request.resource))
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
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      action = Ash.Resource.Info.primary_action!(request.resource, :update).name

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(relationship_name, request.resource_identifiers,
        type: :remove
      )
      |> Ash.Changeset.for_update(action, Request.opts(request))
      |> api.update()
      |> api.load(fields(request, request.resource))
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
    chain(request, fn %{api: api, assigns: %{result: result}} = request ->
      result
      |> Ash.Changeset.for_destroy(request.action.name, %{}, Request.opts(request))
      |> api.destroy()
      |> case do
        :ok ->
          Request.assign(request, :result, nil)

        {:error, error} ->
          Request.add_error(request, error, :destroy)
      end
    end)
  end

  defp path_filter(path_params, resource) do
    Enum.reduce(path_params, %{}, fn {key, value}, acc ->
      case Ash.Resource.Info.public_attribute(resource, key) do
        nil ->
          acc

        attribute ->
          Map.put(acc, attribute.name, value)
      end
    end)
  end

  def fetch_record_from_path(request, through_resource \\ nil) do
    chain(request, fn %{api: api, resource: request_resource} = request ->
      resource = through_resource || request_resource

      filter = path_filter(request.path_params, resource)

      action =
        if through_resource || request.action.type != :read do
          Ash.Resource.Info.primary_action!(resource, :read).name
        else
          request.action.name
        end

      fields_to_load =
        if through_resource do
          []
        else
          fields(request, request.resource)
        end

      resource
      |> Ash.Query.filter(^filter)
      |> Ash.Query.load(fields_to_load ++ (request.includes_keyword || []))
      |> Ash.Query.for_read(
        action,
        request.arguments,
        Keyword.put(Request.opts(request), :page, false)
      )
      |> api.read_one()
      |> case do
        {:ok, nil} ->
          error = Error.NotFound.new(filter: filter, resource: resource)
          Request.add_error(request, error, :fetch_from_path)

          Request.add_error(request, error, :fetch_from_path)

        {:ok, record} ->
          request
          |> Request.assign(:result, record)
          |> Request.assign(:record_from_path, record)

        {:error, error} ->
          Request.add_error(request, error, :fetch_from_path)
      end
    end)
  end

  def fetch_related(request) do
    request
    |> chain(fn %{
                  api: api,
                  assigns: %{result: %source_resource{} = record},
                  relationship: relationship
                } = request ->
      relationship = Ash.Resource.Info.public_relationship(source_resource, relationship)

      sort = request.sort || default_sort(request.resource)

      load_params =
        if Map.get(request.assigns, :page) do
          [page: request.assigns.page]
        else
          []
        end

      destination_query =
        relationship.destination
        |> Ash.Query.new(request.api)
        |> Ash.Query.filter(^request.filter)
        |> Ash.Query.sort(sort)
        |> Ash.Query.load(request.includes_keyword)
        |> Ash.Query.load(fields(request, request.resource))
        |> Ash.Query.put_context(:override_api_params, load_params)

      origin_query =
        source_resource
        |> Ash.Query.new(request.api)
        |> Ash.Query.load([{relationship.name, destination_query}])
        |> Ash.Query.set_tenant(request.tenant)

      case api.load(
             record,
             origin_query,
             Request.load_opts(request)
           ) do
        {:ok, record} ->
          paginated_result =
            record
            |> Map.get(relationship.name)
            |> paginator_or_list()

          request
          |> Request.assign(:record_from_path, record)
          |> Request.assign(:result, paginated_result)

        {:error, error} ->
          Request.add_error(request, error, :fetch_related)
      end
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
    Map.get(request.fields, resource) || []
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
            Error.InvalidPagination.new(source_parameter: "page[#{parameter}]"),
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

  # @spec with_request(
  #         Plug.Conn.t(),
  #         Ash.Resource.t(),
  #         Ash.action(),
  #         (AshJsonApi.Request.t() -> Plug.Conn.t())
  #       ) :: Plug.Conn.t()
  # def with_request(conn, resource, action, function) do
  #   case AshJsonApi.Request.from(conn, resource, action) do
  #     %{errors: []} = request ->
  #       function.(request)

  #     %{errors: errors} = request ->
  #       Response.render_errors(conn, request, errors)
  #   end
  # end
end
