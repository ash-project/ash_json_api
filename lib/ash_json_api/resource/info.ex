defmodule AshJsonApi.Resource.Info do
  @moduledoc "Introspection helpers for AshJsonApi.Resource"

  alias Spark.Dsl.Extension

  def type(resource) do
    Extension.get_opt(resource, [:json_api], :type, nil, false)
  end

  def derive_filter?(resource) do
    Extension.get_opt(resource, [:json_api], :derive_filter?, true, false)
  end

  def derive_sort?(resource) do
    Extension.get_opt(resource, [:json_api], :derive_sort, true, false)
  end

  def always_include_linkage(resource) do
    Extension.get_opt(resource, [:json_api], :always_include_linkage, [], false)
  end

  def includes(resource) do
    Extension.get_opt(resource, [:json_api], :includes, [], false)
  end

  def action_names_in_schema(resource) do
    Extension.get_opt(resource, [:json_api], :action_names_in_schema, [], false)
  end

  def base_route(resource) do
    Extension.get_opt(resource, [:json_api, :routes], :base, "/", false)
  end

  def primary_key_fields(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :keys, [], false)
  end

  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :delimiter, [], false)
  end

  def routes(resource, domain_or_domains \\ []) do
    module =
      if is_atom(resource) do
        resource
      else
        Spark.Dsl.Extension.get_persisted(resource, :module)
      end

    domain_or_domains
    |> List.wrap()
    |> Enum.flat_map(&AshJsonApi.Domain.Info.routes/1)
    |> Enum.filter(&(&1.resource == module))
    |> Enum.concat(Extension.get_entities(resource, [:json_api, :routes]))
  end

  def include_nil_values?(resource) do
    Extension.get_opt(resource, [:json_api], :include_nil_values?, nil, true)
  end

  def default_fields(resource) do
    Extension.get_opt(resource, [:json_api], :default_fields, nil, true)
  end
end
