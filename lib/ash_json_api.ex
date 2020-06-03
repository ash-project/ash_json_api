defmodule AshJsonApi do
  @moduledoc """
  Tools for introspecting ash json api resources/apis.
  """
  def route(resource, criteria \\ %{}) do
    resource
    |> routes()
    |> Enum.find(fn route ->
      Map.take(route, Map.keys(criteria)) == criteria
    end)
  end

  def join_fields(resource, association) do
    join_fields(resource)[association]
  end

  def join_fields(resource) do
    resource.json_api_join_fields()
  end

  def routes(resource) do
    resource.json_api_routes()
  end

  def fields(resource) do
    resource.json_api_fields()
  end

  def includes(resource) do
    resource.json_api_includes()
  end

  def host(api) do
    api.host()
  end

  def prefix(api) do
    api.prefix()
  end

  def serve_schema(api) do
    api.serve_schema()
  end

  @doc false
  # TODO: Ensure that resource routes are created in an order that causes them not to conflict
  def sanitize_routes(_relationships, all_routes) do
    all_routes
    |> Enum.group_by(fn route ->
      {route.method, route.route}
    end)
    |> Enum.flat_map(fn {{method, route}, group} ->
      case group do
        [route] ->
          [route]

        _ ->
          raise "Duplicate routes defined for #{method}: #{route}"
      end
    end)
  end
end
