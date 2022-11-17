defmodule AshJsonApi.Api do
  @json_api %Spark.Dsl.Section{
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
    modules: [:router],
    schema: [
      router: [
        type: :atom,
        doc: "The router that you created for this Api. Use by test helpers to send requests"
      ],
      prefix: [
        type: :string,
        doc: "The route prefix at which you are serving the JSON:API"
      ],
      serve_schema?: [
        type: :boolean,
        doc: "Whether or not create a /schema route that serves the JSON schema of your API",
        default: false
      ],
      serve_open_api?: [
        type: :boolean,
        doc: "Whether or not create a /openapi route that serves the OpenAPI schema of your API",
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

  @sections [@json_api]

  @moduledoc """
  The entrypoint for adding JSON:API behavior to an Ash API

  # Table of Contents
  #{Spark.Dsl.Extension.doc_index(@sections)}

  #{Spark.Dsl.Extension.doc(@sections)}
  """

  use Spark.Dsl.Extension, sections: @sections
end
