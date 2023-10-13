defmodule AshJsonApi.Api.Verifiers.VerifyOpenApiGrouping do
  @moduledoc """
  Ensures that tag is present if group_by is :api
  """
  use Spark.Dsl.Verifier

  def verify(dsl) do
    tag = AshJsonApi.Api.Info.tag(dsl)
    group_by = AshJsonApi.Api.Info.group_by(dsl)

    unless group_by === :api && tag !== "" do
      raise Spark.Error.DslError.exception(
              module: dsl,
              path: [:json_api, :open_api, :tag],
              message: """
              Tag should have a value if group_by has is configured with :api
              """
            )
    end

    :ok
  end
end
