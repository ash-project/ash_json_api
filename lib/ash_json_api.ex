defmodule AshJsonApi do
  @moduledoc """
  Introspection functions for `AshJsonApi` apis.

  For Api DSL documentation, see `AshJsonApi.Api`.

  For Resource DSL documentation, see `AshJsonApi.Resource`
  """
  alias Ash.Dsl.Extension

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
end
