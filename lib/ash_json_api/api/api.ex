defmodule AshJsonApi.Api do
  @moduledoc "The entrypoint for adding JSON:API behavior to an Ash API"

  @json_api %Ash.Dsl.Section{
    name: :json_api,
    describe: """
    Global configuration for JSON:API
    """,
    schema: [
      prefix: [
        type: :string,
        doc: "The route prefix at which you are serving the JSON:API"
      ],
      serve_schema?: [
        type: :boolean,
        doc: "Whether or not create a /schema route that serves the JSON schema of your API",
        default: false
      ],
      authorize?: [
        type: :boolean,
        doc: "Whether or not to perform authorization for this API",
        default: true
      ],
      log_errors?: [
        type: :boolean,
        doc: "Whether or not to log any errors produced",
        default: true
      ]
    ]
  }

  @transformers [AshJsonApi.Api.Transformers.CreateRouter]

  use Ash.Dsl.Extension, sections: [@json_api], transformers: @transformers
end
