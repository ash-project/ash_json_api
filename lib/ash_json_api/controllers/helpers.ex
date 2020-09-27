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
      params =
        if AshJsonApi.authorize?(request.api) do
          [actor: request.actor]
        else
          []
        end

      page_params = Map.get(request.assigns, :page, %{})

      request.resource
      |> Ash.Query.new(request.api)
      |> Ash.Query.load(request.includes_keyword)
      |> Ash.Query.limit(page_params[:limit])
      |> Ash.Query.offset(page_params[:offset])
      |> Ash.Query.filter(request.filter)
      |> Ash.Query.sort(request.sort)
      |> Ash.Query.load(fields(request, request.resource))
      |> request.api.read(params)
      |> case do
        {:ok, results} ->
          page = %AshJsonApi.Paginator{
            results: results,
            limit: page_params[:limit],
            offset: page_params[:offset]
          }

          Request.assign(request, :result, page)

        {:error, error} ->
          Request.add_error(request, error, :read)
      end
    end)
  end

  def create_record(request) do
    chain(request, fn %{api: api, resource: resource} ->
      params =
        if AshJsonApi.authorize?(request.api) do
          [
            action: request.action,
            actor: request.actor
          ]
        else
          [
            action: request.action
          ]
        end

      resource
      |> Ash.Changeset.new(request.attributes || %{})
      |> replace_changeset_relationships(request.relationships || %{})
      |> api.create(params)
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
      params =
        if AshJsonApi.authorize?(request.api) do
          [
            action: request.action,
            actor: request.actor
          ]
        else
          [
            action: request.action
          ]
        end

      result
      |> Ash.Changeset.new(request.attributes || %{})
      |> replace_changeset_relationships(request.relationships || %{})
      |> api.update(params)
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
      params =
        if AshJsonApi.authorize?(request.api) do
          [actor: request.actor]
        else
          []
        end

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.append_to_relationship(relationship_name, request.resource_identifiers)
      |> api.update(params)
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
      params =
        if AshJsonApi.authorize?(request.api) do
          [actor: request.actor]
        else
          []
        end

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.replace_relationship(relationship_name, request.resource_identifiers)
      |> api.update(params)
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
      params = [
        relationships: %{
          relationship_name => %{
            remove: request.resource_identifiers
          }
        }
      ]

      params =
        if AshJsonApi.authorize?(request.api) do
          Keyword.put(params, :actor, request.actor)
        else
          params
        end

      result
      |> Ash.Changeset.new()
      |> Ash.Changeset.remove_from_relationship(relationship_name, request.resource_identifiers)
      |> api.update(params)
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
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      params =
        if AshJsonApi.authorize?(request.api) do
          [
            action: request.action,
            actor: request.actor
          ]
        else
          [action: request.action]
        end

      case api.destroy(result, params) do
        :ok ->
          Request.assign(request, :result, nil)

        {:error, error} ->
          Request.add_error(request, error, :destroy)
      end
    end)
  end

  defp path_filter(path_params, resource) do
    Enum.reduce(path_params, %{}, fn {key, value}, acc ->
      case Ash.Resource.attribute(resource, key) do
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

      query = Ash.Query.filter(resource, filter)

      params =
        if through_resource || request.action.type != :read do
          []
        else
          [
            action: request.action
          ]
        end

      params =
        if AshJsonApi.authorize?(api) do
          Keyword.put(params, :actor, request.actor)
        else
          params
        end

      fields_to_load =
        if through_resource do
          []
        else
          fields(request, request.resource)
        end

      with {:ok, [record]} when not is_nil(record) <- api.read(query, params),
           {:ok, record} <- api.load(record, fields_to_load) do
        request
        |> Request.assign(:result, record)
        |> Request.assign(:record_from_path, record)
      else
        {:ok, _} ->
          error = Error.NotFound.new(filter: filter, resource: resource)
          Request.add_error(request, error, :fetch_from_path)

        {:error, error} ->
          Request.add_error(request, error, :fetch_from_path)
      end
    end)
  end

  def fetch_related(request, paginate? \\ true) do
    request
    |> chain(fn %{
                  api: api,
                  assigns: %{result: %source_resource{} = record},
                  relationship: relationship
                } = request ->
      relationship = Ash.Resource.relationship(source_resource, relationship)

      params = [
        action: request.action
      ]

      sort = request.sort || default_sort(request.resource)

      destination_query =
        relationship.destination
        |> Ash.Query.new(request.api)
        |> Ash.Query.filter(request.filter)
        |> Ash.Query.sort(sort)
        |> Ash.Query.load(request.includes_keyword)
        |> Ash.Query.load(fields(request, request.resource))

      pagination_params = Map.get(request.assigns, :page, %{})

      destination_query =
        if paginate? do
          destination_query
          |> Ash.Query.sort(Ash.Resource.primary_key(request.resource))
          |> Ash.Query.limit(pagination_params[:limit])
          |> Ash.Query.offset(pagination_params[:offset])
        else
          destination_query
        end

      origin_query =
        source_resource
        |> Ash.Query.new(request.api)
        |> Ash.Query.load([{relationship.name, destination_query}])

      params =
        if AshJsonApi.authorize?(api) do
          Keyword.put(params, :actor, request.actor)
        else
          params
        end

      case api.load(
             record,
             origin_query,
             params
           ) do
        {:ok, record} ->
          paginated_result =
            record
            |> Map.get(relationship.name)
            |> List.wrap()
            |> maybe_paginate(pagination_params, paginate?)

          request
          |> Request.assign(:record_from_path, record)
          |> Request.assign(:result, paginated_result)

        {:error, error} ->
          Request.add_error(request, error, :fetch_related)
      end
    end)
  end

  defp fields(request, resource) do
    Map.get(request.fields, resource) || []
  end

  defp default_sort(resource) do
    created_at =
      Ash.Resource.attribute(resource, :created_at) ||
        Ash.Resource.attribute(resource, :inserted_at)

    if created_at do
      [{created_at.name, :asc}]
    else
      Ash.Resource.primary_key(resource)
    end
  end

  defp maybe_paginate(records, pagination_params, paginate?) do
    if paginate? do
      %AshJsonApi.Paginator{
        limit: pagination_params[:limit],
        offset: pagination_params[:offset],
        results: records
      }
    else
      records
    end
  end

  defp replace_changeset_relationships(changeset, relationships) do
    Enum.reduce(relationships, changeset, fn {key, value}, changeset ->
      Ash.Changeset.replace_relationship(changeset, key, value)
    end)
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
    |> add_limit()
    |> add_offset()
  end

  defp add_limit(request) do
    with %{"page" => page} <- request.query_params,
         %{"limit" => limit} <- page,
         {:integer, {integer, ""}} <- {:integer, Integer.parse(limit)} do
      Request.update_assign(request, :page, %{limit: integer}, &Map.put(&1, :limit, integer))
    else
      {:integer, {_integer, _remaining}} ->
        Request.add_error(request, Error.InvalidPagination.new(parameter: "page[limit]"), :read)

      _ ->
        request
    end
  end

  defp add_offset(request) do
    with %{"page" => page} <- request.query_params,
         %{"offset" => offset} <- page,
         {:integer, {integer, ""}} <- {:integer, Integer.parse(offset)} do
      Request.update_assign(request, :page, %{offset: integer}, &Map.put(&1, :offset, integer))
    else
      {:integer, {_integer, _remaining}} ->
        Request.add_error(request, Error.InvalidPagination.new(parameter: "page[offset]"), :read)

      _ ->
        request
    end
  end

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
  #         Ash.resource(),
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
