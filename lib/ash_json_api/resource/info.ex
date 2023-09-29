defmodule AshJsonApi.Resource.Info do
  @moduledoc "Introspection helpers for AshJsonApi.Resource"

  alias Spark.Dsl.Extension

  def type(resource) do
    Extension.get_opt(resource, [:json_api], :type, nil, false)
  end

  def includes(resource) do
    Extension.get_opt(resource, [:json_api], :includes, [], false)
  end

  def base_route(resource) do
    Extension.get_opt(resource, [:json_api, :routes], :base, nil, false)
  end

  def primary_key_fields(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :keys, [], false)
  end

  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :delimiter, [], false)
  end

  def routes(resource) do
    Extension.get_entities(resource, [:json_api, :routes])
  end

  def include_nil_values?(resource) do
    Extension.get_opt(resource, [:json_api], :include_nil_values?, nil, true)
  end
end
