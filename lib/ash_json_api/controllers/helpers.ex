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
      params = %{
        user: request.user,
        side_load: request.includes_keyword,
        action: request.action,
        page: Map.get(request.assigns, :page, %{}),
        authorize?: true,
        filter: request.filter,
        sort: request.sort
      }

      case request.api.read(request.resource, params) do
        {:ok, paginator} ->
          Request.assign(request, :result, paginator)

        {:error, :unauthorized} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, db_error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "Failed to read resource #{inspect(request.resource)} | #{inspect(db_error)}"
            )

          Request.add_error(request, error)
      end
    end)
  end

  def create_record(request) do
    chain(request, fn %{api: api, resource: resource} ->
      params = %{
        user: request.user,
        side_load: request.includes_keyword,
        action: request.action,
        authorize?: true,
        attributes: request.attributes,
        relationships: request.relationships
      }

      case api.create(resource, params) do
        {:ok, record} ->
          Request.assign(request, :result, record)

        {:error, :unauthorized} ->
          error = Error.Forbidden.new([])
          Request.add_error(request, error)

        {:error, _error} ->
          error =
            Error.FrameworkError.new(
              internal_description:
                "something went wrong while creating. Error messaging is incomplete so far."
            )

          Request.add_error(request, error)
      end
    end)
  end

  def fetch_record_from_path(request) do
    request
    |> fetch_id_path_param()
    |> chain(fn %{api: api, resource: resource} = request ->
      id = request.assigns.id

      params = %{
        user: request.user,
        side_load: request.includes_keyword,
        action: request.action,
        authorize?: api.authorize?
      }

      case api.get(resource, id, params) do
        {:ok, nil} ->
          error = Error.NotFound.new(id: id, resource: resource)
          Request.add_error(request, error)

        {:ok, record} ->
          Request.assign(request, :result, record)

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
