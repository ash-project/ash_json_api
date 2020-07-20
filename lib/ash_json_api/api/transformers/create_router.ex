defmodule AshJsonApi.Api.Transformers.CreateRouter do
  @moduledoc "Defines a router module to be included in the router"

  use Ash.Dsl.Transformer
  alias Ash.Dsl.Transformer
  alias AshJsonApi.Api.Router

  @impl true
  def transform(api, dsl) do
    module_name = Module.concat(api, Router)

    module_name =
      Router.define_router(
        module_name,
        api,
        Ash.Api.resources(api),
        AshJsonApi.prefix(api),
        AshJsonApi.serve_schema?(api)
      )

    dsl = Transformer.persist(dsl, {api, :ash_json_api, :router}, module_name)

    {:ok, dsl}
  end

  @impl true
  def after?(Ash.Api.Transformers.EnsureResourcesCompiled), do: true
  def after?(_), do: false
end
