defmodule AshJsonApi.Domain do
  @open_api %Spark.Dsl.Section{
    name: :open_api,
    describe: "OpenAPI configurations",
    examples: [
      """
      json_api do
        ...
        open_api do
          tag "Users"
          group_by :api
        end
      end
      """
    ],
    schema: [
      tag: [
        type: :string,
        doc: "Tag to be used when used by :group_by"
      ],
      group_by: [
        type: {:in, [:domain, :resource]},
        doc: "Group by :domain or :resource",
        default: :resource
      ]
    ]
  }

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
      serve_schema?: "Use the `json_schema` option to `use AshJsonApi.Router` instead."
    ],
    schema: [
      router: [
        type: :atom,
        doc: "The router that you created for this Domain. Use by test helpers to send requests"
      ],
      show_raised_errors?: [
        type: :boolean,
        default: false,
        doc:
          "For security purposes, if an error is *raised* then Ash simply shows a generic error. If you want to show those errors, set this to true."
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
      authorize?: [
        type: :boolean,
        doc: "Whether or not to perform authorization on requests.",
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
    ],
    sections: [@open_api]
  }

  @verifiers [AshJsonApi.Domain.Verifiers.VerifyOpenApiGrouping]

  @sections [@json_api]

  @moduledoc """
  The entrypoint for adding JSON:API behavior to an Ash domain
  """

  use Spark.Dsl.Extension, sections: @sections, verifiers: @verifiers
end
