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

  def require_type_on_create?(domain) do
    Extension.get_opt(domain, [:json_api], :require_type_on_create?, false, true)
  end
end
