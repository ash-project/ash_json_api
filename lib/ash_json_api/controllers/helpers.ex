defmodule AshJsonApi.Controllers.Helpers do
  @moduledoc """
  Tools for control flow around a request, and common controller utilities.

  `chain/2` lets us pipe cleanly, only doing stateful things if no errors
  have been generated yet.

  TODO: Ash will need to have its own concept of errors, and this
  will need to convert those errors into API level errors.
  """
  alias AshJsonApi.Controllers.Response
  alias AshJsonApi.{Error, Request}

  def render_or_render_errors(request, conn, function) do
    chain(request, function,
      fallback: fn request ->
        Response.render_errors(conn, request)
      end
    )
  end

  def fetch_includes(request) do
    chain(request, fn request ->
      {new_result, includes} =
        AshJsonApi.Includes.Includer.get_includes(request.assigns.result, request)

      request
      |> Request.assign(:result, new_result)
      |> Request.assign(:includes, includes)
    end)
  end

  def fetch_records(request) do
    chain(request, fn request ->
      params =
        if request.api.authorize? do
          [action: request.action, authorization: [user: request.user]]
        else
          [action: request.action]
        end

      page_params = Map.get(request.assigns, :page, %{})

      query =
        request.resource
        |> request.api.query()
        |> Ash.Query.side_load(request.includes_keyword)
        |> Ash.Query.limit(page_params[:limit])
        |> Ash.Query.offset(page_params[:offset])
        |> Ash.Query.filter(request.filter)
        |> Ash.Query.sort(request.sort)

      case request.api.read(query, params) do
        {:ok, results} ->
          page = %AshJsonApi.Paginator{
            results: results,
            limit: page_params[:limit],
            offset: page_params[:offset]
          }

          Request.assign(request, :result, page)

        {:error, %{class: :forbidden}} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, error} ->
          # TODO: map ash errors to json api errors
          error =
            Error.FrameworkError.new(
              internal_description:
                "Failed to read resource #{inspect(request.resource)} | #{inspect(error)}"
            )

          Request.add_error(request, error)
      end
    end)
  end

  defp side_load_query(request) do
    request.resource
    |> request.api.query()
    |> Ash.Query.side_load(request.includes_keyword)
  end

  def create_record(request) do
    chain(request, fn %{api: api, resource: resource} ->
      params =
        if request.api.authorize? do
          [
            action: request.action,
            authorization: [user: request.user],
            side_load: side_load_query(request),
            attributes: request.attributes,
            relationships: request.relationships
          ]
        else
          [
            action: request.action,
            side_load: side_load_query(request),
            attributes: request.attributes,
            relationships: request.relationships
          ]
        end

      case api.create(resource, params) do
        {:ok, record} ->
          Request.assign(request, :result, record)

        {:error, :unauthorized} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "something went wrong while creating. Error messaging is incomplete so far: #{
                  inspect(error)
                }"
            )

          Request.add_error(request, error)
      end
    end)
  end

  def update_record(request) do
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      params =
        if request.api.authorize? do
          [
            action: request.action,
            authorization: [user: request.user],
            side_load: side_load_query(request),
            attributes: request.attributes,
            relationships: request.relationships
          ]
        else
          [
            action: request.action,
            side_load: side_load_query(request),
            attributes: request.attributes,
            relationships: request.relationships
          ]
        end

      case api.update(result, params) do
        {:ok, record} ->
          Request.assign(request, :result, record)

        {:error, :unauthorized} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "something went wrong while updating. Error messaging is incomplete so far: #{
                  inspect(error)
                }"
            )

          Request.add_error(request, error)
      end
    end)
  end

  def add_to_relationship(request, relationship_name) do
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      params = [
        relationships: %{
          relationship_name => %{
            add: request.resource_identifiers
          }
        }
      ]

      params =
        if request.api.authorize? do
          Keyword.put(params, :authorization, user: request.user)
        else
          params
        end

      case api.update(result, params) do
        {:ok, updated} ->
          Request.assign(request, :result, Map.get(updated, relationship_name))

        {:error, error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "something went wrong while adding to relationship. Error messaging is incomplete so far: #{
                  inspect(error)
                }"
            )

          Request.add_error(request, error)
      end
    end)
  end

  def replace_relationship(request, relationship_name) do
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      params = [
        relationships: %{
          relationship_name => %{
            replace: request.resource_identifiers
          }
        }
      ]

      params =
        if request.api.authorize? do
          Keyword.put(params, :authorization, user: request.user)
        else
          params
        end

      case api.update(result, params) do
        {:ok, updated} ->
          Request.assign(request, :result, Map.get(updated, relationship_name))

        {:error, error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "something went wrong while adding to relationship. Error messaging is incomplete so far: #{
                  inspect(error)
                }"
            )

          Request.add_error(request, error)
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
        if request.api.authorize? do
          Keyword.put(params, :authorization, user: request.user)
        else
          params
        end

      case api.update(result, params) do
        {:ok, updated} ->
          Request.assign(request, :result, Map.get(updated, relationship_name))

        {:error, error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "something went wrong while adding to relationship. Error messaging is incomplete so far: #{
                  inspect(error)
                }"
            )

          Request.add_error(request, error)
      end
    end)
  end

  def destroy_record(request) do
    chain(request, fn %{api: api, assigns: %{result: result}} ->
      params =
        if request.api.authorize? do
          [
            action: request.action,
            authorization: [user: request.user]
          ]
        else
          [action: request.action]
        end

      case api.destroy(result, params) do
        :ok ->
          Request.assign(request, :result, nil)

        {:error, :unauthorized} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "something went wrong while deleting. Error messaging is incomplete so far: #{
                  inspect(error)
                }"
            )

          Request.add_error(request, error)
      end
    end)
  end

  def fetch_record_from_path(request, through_resource \\ nil) do
    request
    |> fetch_id_path_param()
    |> chain(fn %{api: api, resource: request_resource} = request ->
      resource = through_resource || request_resource
      id = request.assigns.id

      params =
        if through_resource do
          []
        else
          [
            side_load: request.includes_keyword,
            action: request.action
          ]
        end

      params =
        if api.authorize? do
          Keyword.put(params, :authorization, user: request.user)
        else
          params
        end

      case api.get(resource, id, params) do
        {:ok, nil} ->
          error = Error.NotFound.new(id: id, resource: resource)
          Request.add_error(request, error)

        {:ok, record} ->
          request
          |> Request.assign(:result, record)
          |> Request.assign(:record_from_path, record)

        {:error, :unauthorized} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, db_error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "failed to retrieve record by id for resource: #{inspect(resource)}, id: #{
                  inspect(id)
                } | #{inspect(db_error)}"
            )

          Request.add_error(request, error)
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
      relationship = Ash.relationship(source_resource, relationship)

      params = [
        action: request.action
      ]

      destination_query =
        relationship.destination
        |> api.query()
        |> Ash.Query.filter(request.filter)
        |> Ash.Query.sort(request.sort)
        |> Ash.Query.side_load(request.includes_keyword)

      pagination_params = Map.get(request.assigns, :page, %{})

      destination_query =
        if paginate? do
          destination_query
          # TODO: This is a fallback sort for predictable pagination, we should get smarter about it
          |> Ash.Query.sort(Ash.primary_key(request.resource))
          |> Ash.Query.limit(pagination_params[:limit])
          |> Ash.Query.offset(pagination_params[:offset])
        else
          destination_query
        end

      origin_query =
        source_resource
        |> api.query()
        |> Ash.Query.side_load([{relationship.name, destination_query}])

      params =
        if api.authorize? do
          Keyword.put(params, :authorization, user: request.user)
        else
          params
        end

      case api.side_load(
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

          Request.assign(request, :result, paginated_result)

        {:error, :unauthorized} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, db_error} ->
          error =
            Error.FrameworkError.new(
              internal_description: "failed to load related #{inspect(db_error)}"
            )

          Request.add_error(request, error)
      end
    end)
  end

  defp maybe_paginate(records, pagination_params, paginate?) do
    if paginate? do
      %AshJsonApi.Paginator{
        limit: pagination_params[:limit],
        offset: pagination_params[:offset],
        results: records
      }
    else
    end
  end

  def fetch_id_path_param(request) do
    chain(request, fn request ->
      case request.path_params do
        %{"id" => id} ->
          Request.assign(request, :id, id)

        _ ->
          error =
            Error.FrameworkError.new(
              internal_description: "id path parameter not present in get route: #{request.url}"
            )

          Request.add_error(request, error)
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
        Request.add_error(request, Error.InvalidPagination.new(parameter: "page[limit]"))

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
        Request.add_error(request, Error.InvalidPagination.new(parameter: "page[offset]"))

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
