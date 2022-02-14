defmodule AshJsonApi.Api do
  @json_api %Ash.Dsl.Section{
    name: :json_api,
    describe: """
    Global configuration for JSON:API
    """,
    examples: [
      """
      json_api do
        prefix "/json_api"
        serve_schema? true
        log_errors? true
      end
      """
    ],
    schema: [
      prefix: [
        type: :string,
        doc: "The route prefix at which you are serving the JSON:API"
      ],
      key_transformer: [
        type: :string,
        doc: "Transformer to use on attribute names.",
        default: "snake_case",
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
  @sections [@json_api]

  @moduledoc """
  The entrypoint for adding JSON:API behavior to an Ash API

  # Table of Contents
  #{Ash.Dsl.Extension.doc_index(@sections)}

  #{Ash.Dsl.Extension.doc(@sections)}
  """

  use Ash.Dsl.Extension, sections: @sections, transformers: @transformers
end
