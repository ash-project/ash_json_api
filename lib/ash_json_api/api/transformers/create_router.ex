defmodule AshJsonApi.Api.Transformers.CreateRouter do
  @moduledoc "Defines a router module to be included in the router"

  use Ash.Dsl.Transformer
  alias Ash.Dsl.Transformer
  alias AshJsonApi.Api.Router

  @impl true
  def transform(api, dsl) do
    module_name =
      Router.define_router(
        api,
        Ash.Api.resources(api),
        AshJsonApi.prefix(api),
        AshJsonApi.serve_schema?(api)
      )

    Transformer.persist_to_runtime(api, {api, :ash_json_api, :router}, module_name)

    {:ok, dsl}
  end

  @impl true
  def compile_time_only?, do: true
end
