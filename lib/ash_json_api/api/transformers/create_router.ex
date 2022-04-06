defmodule AshJsonApi.Api.Transformers.CreateRouter do
  @moduledoc "Defines a router module to be included in the router"

  use Ash.Dsl.Transformer
  alias AshJsonApi.Api.Router

  @impl true
  def after_compile?, do: true

  @impl true
  def transform(api, dsl) do
    registry = Ash.Api.registry(api)

    resources =
      if registry do
        Code.ensure_compiled!(registry)

        Ash.Registry.entries(registry)
      else
        []
      end

    Router.define_router(
      AshJsonApi.router(api),
      api,
      resources,
      AshJsonApi.prefix(api),
      AshJsonApi.serve_schema?(api)
    )

    {:ok, dsl}
  end
end
