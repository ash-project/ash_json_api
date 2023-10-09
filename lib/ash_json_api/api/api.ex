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
        log_errors? true
      end
      """
    ],
    modules: [:router],
    deprecations: [
      serve_schema?: "Use the `json_schema` option to `use AshJsonApi.Api.Router` instead."
    ],
    schema: [
      router: [
        type: :atom,
        doc: "The router that you created for this Api. Use by test helpers to send requests"
      ],
      prefix: [
        type: :string,
        doc: "The route prefix at which you are serving the JSON:API"
      ],
      open_api: [
        type: :map,
        doc: "OpenAPI configurations",
        keys: [
          tag: [
            type: :string,
            doc: "Tag to be used when used by :group_by"
          ],
          group_by: [
            type: {:in, [:api, :resource]},
            doc: "Group by :api or :resource"
          ]
        ]
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
      ],
      include_nil_values?: [
        type: :boolean,
        doc: "Whether or not to include properties for values that are nil in the JSON output",
        default: true
      ]
    ]
  }

  @sections [@json_api]

  @moduledoc """
  The entrypoint for adding JSON:API behavior to an Ash API
  """

  use Spark.Dsl.Extension, sections: @sections
end
