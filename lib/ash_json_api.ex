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

  def key_transformer(api) do
    Extension.get_opt(api, [:json_api], :key_transformer, false, true)
  end


  defmacro forward(path, api, opts \\ []) do
    quote bind_quoted: [path: path, api: api, opts: opts] do
      case Code.ensure_compiled(api) do
        {:module, module} ->
          api = AshJsonApi.router(api)
          forward(path, api, opts)

        _ ->
          # We used to raise here, but this failing almost always implies
          # a compilation error in the api, which will be more informative
          # if we just let that be raised
          :ok
      end
    end
  end

  def router(api) do
    Extension.get_persisted(api, :router, nil)
  end
end
