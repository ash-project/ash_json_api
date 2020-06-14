defmodule AshJsonApi do
  @moduledoc """
  Tools for introspecting ash json api resources/apis.
  """
  alias Ash.Dsl.Extension

  def route(resource, criteria \\ %{}) do
    resource
    |> routes()
    |> Enum.find(fn route ->
      Map.take(route, Map.keys(criteria)) == criteria
    end)
  end

  def type(resource) do
    Extension.get_opt(resource, [:json_api], :type)
  end

  def routes(resource) do
    Extension.get_entities(resource, [:json_api, :routes])
  end

  def fields(resource) do
    Extension.get_opt(resource, [:json_api], :fields)
  end

  def includes(resource) do
    Extension.get_opt(resource, [:json_api], :includes)
  end

  def prefix(api) do
    Extension.get_opt(api, [:json_api], :prefix)
  end

  def serve_schema?(api) do
    Extension.get_opt(api, [:json_api], :serve_schema?)
  end

  def authorize?(api) do
    Extension.get_opt(api, [:json_api], :authorize?)
  end

  def router(api) do
    :persistent_term.get({api, :ash_json_api, :router}, nil)
  end

  def base_route(resource) do
    Extension.get_opt(resource, [:json_api, :routes], :base)
  end
end
