# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Domain.Info do
  @moduledoc "Introspection helpers for AshJsonApi.Domain"
  alias Spark.Dsl.Extension

  def tag(domain) do
    Extension.get_opt(domain, [:json_api, :open_api], :tag, nil, true)
  end

  def show_raised_errors?(domain) do
    Extension.get_opt(domain, [:json_api], :show_raised_errors?, false, true)
  end

  def group_by(domain) do
    Extension.get_opt(domain, [:json_api, :open_api], :group_by, nil, true)
  end

  def prefix(domain) do
    Extension.get_opt(domain, [:json_api], :prefix, nil, true)
  end

  def serve_schema?(domain) do
    Extension.get_opt(domain, [:json_api], :serve_schema?, false, true)
  end

  @doc """
  Returns the routes defined in the domain's `json_api.routes` section.

  The result is a flat list of `%AshJsonApi.Resource.Route{}` structs. Any
  `base_route` blocks (including nested ones) are flattened at compile time:
  each base route's prefix is already joined into the route's `route`, and
  `resource` is filled in from the enclosing `base_route` when the route
  doesn't set its own.

  The domain's `prefix` is *not* included in `route`, and routes defined on
  resources are not returned. Use `AshJsonApi.Resource.Info.routes/2` to get
  every route for a resource across both.

  The following fields are safe to rely on:

    * `:name` - the route's name, used as the OpenAPI `operationId` when set
    * `:resource` - the resource the route's action is defined on
    * `:action` - the name of the action the route calls
    * `:type` - the kind of route, e.g. `:index`, `:get`, `:post`, `:patch`
    * `:method` - the HTTP method, e.g. `:get` or `:post`
    * `:route` - the path, e.g. `"/posts/:id"`, with path params as `:name` segments
  """
  def routes(domain) do
    Extension.get_entities(domain, [:json_api, :routes])
  end

  def authorize?(domain) do
    Extension.get_opt(domain, [:json_api], :authorize?, true, true)
  end

  def log_errors?(domain) do
    Extension.get_opt(domain, [:json_api], :log_errors?, false, true)
  end

  def router(domain) do
    Extension.get_opt(domain, [:json_api], :test_router, nil, true) ||
      Extension.get_opt(domain, [:json_api], :router, nil, false)
  end

  def include_nil_values?(domain) do
    Extension.get_opt(domain, [:json_api], :include_nil_values?, true, true)
  end

  def error_handler(domain) do
    Extension.get_opt(domain, [:json_api], :error_handler, nil, true)
  end

  def require_type_on_create?(domain) do
    Extension.get_opt(domain, [:json_api], :require_type_on_create?, false, true)
  end
end
