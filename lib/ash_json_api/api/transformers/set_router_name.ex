defmodule AshJsonApi.Api.Transformers.SetRouterName do
  @moduledoc "Sets the name of the router module into the dsl"

  use Ash.Dsl.Transformer
  alias Ash.Dsl.Transformer
  alias AshJsonApi.Api.Router

  @impl true
  def transform(api, dsl) do
    module_name = Module.concat(api, Router)

    {:ok, Transformer.persist(dsl, :router, module_name)}
  end
end
