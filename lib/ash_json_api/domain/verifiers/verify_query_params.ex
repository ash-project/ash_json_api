defmodule AshJsonApi.Domain.Verifiers.VerifyQueryParams do
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)

    dsl
    |> AshJsonApi.Domain.Info.routes()
    |> Enum.each(&AshJsonApi.Resource.Verifiers.VerifyQueryParams.verify_route!(&1, module))

    :ok
  end
end
