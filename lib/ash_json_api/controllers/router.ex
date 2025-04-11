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
    prefix =
      conn.request_path
      |> Path.split()
      |> Enum.reverse()
      |> Enum.drop(Enum.count(conn.path_info))
      |> Enum.reverse()
      |> case do
        [] -> "/"
        paths -> Path.join(paths)
      end

    cond do
      conn.method in ["GET", :get] &&
        Enum.any?(domains, &AshJsonApi.Domain.Info.serve_schema?/1) &&
          conn.path_info in [["schema"], ["schema.json"]] ->
        conn
        |> then(fn conn ->
          case opts[:before_dispatch] do
            nil ->
              conn

            {m, f, a} ->
              apply(m, f, [
                conn,
                :json_schema
                | a
              ])

            other ->
              raise "Invalid before_dispatch option: #{inspect(other)}"
          end
        end)
        |> AshJsonApi.Controllers.Schema.call(domains: domains, prefix: prefix)

      open_api_request?(conn, open_api) ->
        conn
        |> then(fn conn ->
          case opts[:before_dispatch] do
            nil ->
              conn

            {m, f, a} ->
              apply(m, f, [
                conn,
                :open_api
                | a
              ])

            other ->
              raise "Invalid before_dispatch option: #{inspect(other)}"
          end
        end)
        |> then(&apply(AshJsonApi.Controllers.OpenApi, :call, [&1, opts]))

      conn.method == "GET" && Enum.any?(json_schema, &(&1 == conn.path_info)) ->
        conn
        |> then(fn conn ->
          case opts[:before_dispatch] do
            nil ->
              conn

            {m, f, a} ->
              apply(m, f, [
                conn,
                :json_schema
                | a
              ])

            other ->
              raise "Invalid before_dispatch option: #{inspect(other)}"
          end
        end)
        |> AshJsonApi.Controllers.Schema.call(Keyword.put(opts, :prefix, prefix))

      true ->
        Enum.find_value(domains, :error, fn domain ->
          case domain.json_api_match_route(conn.method, conn.path_info) do
            {:ok, resource, route, params} ->
              {:ok, domain, resource, route, params}

            :error ->
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
          end
        end)
        |> case do
          :error ->
            conn
            |> then(fn conn ->
              case opts[:before_dispatch] do
                nil ->
                  conn

                {m, f, a} ->
                  apply(m, f, [
                    conn,
                    :not_found
                    | a
                  ])

                other ->
                  raise "Invalid before_dispatch option: #{inspect(other)}"
              end
            end)
            |> AshJsonApi.Controllers.NoRouteFound.call([])

          {:ok, domain, resource, route, params} ->
            conn
            |> Map.update!(:path_params, fn path_params ->
              path_params
              |> Kernel.||(%{})
              |> Map.merge(params)
            end)
            |> then(fn conn ->
              case opts[:before_dispatch] do
                nil ->
                  conn

                {m, f, a} ->
                  apply(m, f, [
                    conn,
                    %{
                      domain: domain,
                      resource: resource,
                      route: route,
                      params: params
                    }
                    | a
                  ])

                other ->
                  raise "Invalid before_dispatch option: #{inspect(other)}"
              end
            end)
            |> route.controller.call(
              domain: domain,
              resource: resource,
              all_domains: domains,
              prefix: prefix,
              action_type: route.action_type,
              route: route,
              relationship: route.relationship,
              action: Ash.Resource.Info.action(resource, route.action)
            )
        end
    end
  end

  defp open_api_request?(conn, open_api) do
    AshJsonApi.OpenApiSpexChecker.has_open_api?() && conn.method == "GET" &&
      Enum.any?(open_api, &(&1 == conn.path_info))
  end
end
