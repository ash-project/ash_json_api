defmodule AshJsonApi.Controllers.Router do
  @moduledoc false

  @dialyzer {:nowarn_function, {:open_api_request?, 2}}

  def init(options) do
    # initialize options
    options
    |> Keyword.update(:domains, [], &List.wrap/1)
    |> Keyword.update(:open_api, [], fn
      true ->
        [["open_api"]]

      other ->
        other
        |> List.wrap()
        |> Enum.map(&String.split(&1, "/", trim: true))
    end)
    |> Keyword.update(:json_schema, [], fn
      true ->
        [["json_schema"]]

      other ->
        other
        |> List.wrap()
        |> Enum.map(&String.split(&1, "/", trim: true))
    end)
    |> Map.new()
    |> Map.put(:original, options)
  end

  def call(conn, %{domains: domains, open_api: open_api, json_schema: json_schema, original: opts}) do
    cond do
      conn.method in ["GET", :get] &&
        Enum.any?(domains, &AshJsonApi.Domain.Info.serve_schema?/1) &&
          conn.path_info in [["schema"], ["schema.json"]] ->
        AshJsonApi.Controllers.Schema.call(conn, domains: domains)

      open_api_request?(conn, open_api) ->
        open_api_opts = open_api_opts(opts)

        AshJsonApi.Controllers.OpenApi.call(conn, open_api_opts)

      conn.method == "GET" && Enum.any?(json_schema, &(&1 == conn.path_info)) ->
        AshJsonApi.Controllers.Schema.call(conn, opts)

      true ->
        Enum.find_value(domains, :error, fn domain ->
          domain
          |> Ash.Domain.Info.resources()
          |> Enum.filter(&(AshJsonApi.Resource in Spark.extensions(&1)))
          |> Enum.find_value(nil, fn resource ->
            case resource.json_api_match_route(conn.method, conn.path_info) do
              {:ok, route, params} ->
                {:ok, domain, resource, route, params}

              :error ->
                nil
            end
          end)
        end)
        |> case do
          :error ->
            AshJsonApi.Controllers.NoRouteFound.call(conn, [])

          {:ok, domain, resource, route, params} ->
            conn
            |> Map.update!(:path_params, fn path_params ->
              path_params
              |> Kernel.||(%{})
              |> Map.merge(params)
            end)
            |> route.controller.call(
              domain: domain,
              resource: resource,
              action_type: route.action_type,
              route: route,
              relationship: route.relationship,
              action: Ash.Resource.Info.action(resource, route.action)
            )
        end
    end
  end

  defp open_api_opts(opts) do
    opts
    |> Keyword.put(:modify, Keyword.get(opts, :modify_open_api))
    |> Keyword.delete(:modify_open_api)
  end

  defp open_api_request?(conn, open_api) do
    AshJSonApi.OpenApiSpexChecker.has_open_api?() && conn.method == "GET" &&
      Enum.any?(open_api, &(&1 == conn.path_info))
  end
end
