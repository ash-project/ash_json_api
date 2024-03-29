defmodule AshJsonApi.Domain.Verifiers.VerifyOpenApiGrouping do
  @moduledoc false

  use Spark.Dsl.Verifier

  def verify(dsl) do
    tag = AshJsonApi.Domain.Info.tag(dsl)
    group_by = AshJsonApi.Domain.Info.group_by(dsl)

    if group_by === :domain and (tag === "" or tag === nil) do
      {:error,
       Spark.Error.DslError.exception(
         module: dsl,
         path: [:json_api, :open_api, :tag],
         message: """
         Tag should have a value if group_by has is configured with :domain

         ```
         open_api do
           tag "Users"
           group_by :api
         end
         ```
         """
       )}
    else
      :ok
    end
  end
end
