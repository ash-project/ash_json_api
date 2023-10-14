defmodule AshJsonApi.Api.Info do
  @moduledoc "Introspection helpers for AshJsonApi.Api"
  alias Spark.Dsl.Extension

  def tag(api) do
    Extension.get_opt(api, [:json_api, :open_api], :tag, nil, true)
  end

  def group_by(api) do
    Extension.get_opt(api, [:json_api, :open_api], :group_by, nil, true)
  end

  def prefix(api) do
    Extension.get_opt(api, [:json_api], :prefix, nil, true)
  end

  def serve_schema?(api) do
    Extension.get_opt(api, [:json_api], :serve_schema?, false, true)
  end

  def authorize?(api) do
    Extension.get_opt(api, [:json_api], :authorize?, true, true)
  end

  def log_errors?(api) do
    Extension.get_opt(api, [:json_api], :log_errors?, false, true)
  end

  def router(api) do
    Extension.get_opt(api, [:json_api], :router, nil, false)
  end

  def include_nil_values?(api) do
    Extension.get_opt(api, [:json_api], :include_nil_values?, true, true)
  end
end
