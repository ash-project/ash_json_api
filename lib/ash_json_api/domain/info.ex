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

  def authorize?(domain) do
    Extension.get_opt(domain, [:json_api], :authorize?, true, true)
  end

  def log_errors?(domain) do
    Extension.get_opt(domain, [:json_api], :log_errors?, false, true)
  end

  def router(domain) do
    Extension.get_opt(domain, [:json_api], :router, nil, false)
  end

  def include_nil_values?(domain) do
    Extension.get_opt(domain, [:json_api], :include_nil_values?, true, true)
  end
end
