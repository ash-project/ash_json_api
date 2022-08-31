defmodule AshJsonApi.DocIndex do
  @moduledoc false

  use Spark.DocIndex,
    otp_app: :ash_json_api,
    guides_from: [
      "documentation/**/*.md"
    ]

  @impl true
  def for_library, do: "ash_json_api"

  @impl true
  def extensions do
    [
      %{
        module: AshJsonApi.Resource,
        name: "AshJsonApi Resource",
        target: "Ash.Resource",
        type: "JSON:API Resource"
      },
      %{
        module: AshJsonApi.Api,
        name: "AshJsonApi Api",
        target: "Ash.Api",
        type: "JSON:API Api"
      }
    ]
  end

  @impl true
  def code_modules do
    [
      {"Introspection",
       [
         AshJsonApi.Resource.Info,
         AshJsonApi.Api.Info
       ]}
    ]
  end
end
