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

  @our_routes AshJsonApi.Resource.routes()
              |> Map.update!(:entities, fn entities ->
                Enum.map(entities, fn entity ->
                  %{
                    entity
                    | args: [:resource | entity.args],
                      schema:
                        entity.schema
                        |> Keyword.put(:resource,
                          type: {:spark, Ash.Resource},
                          doc: "The resource that the route's action is defined on"
                        )
                  }
                end)
              end)

  @route_entities_with_optional_resource AshJsonApi.Resource.routes()
                                         |> Map.get(:entities)
                                         |> Enum.map(fn entity ->
                                           %{
                                             entity
                                             | args: [{:optional, :resource} | entity.args],
                                               schema:
                                                 entity.schema
                                                 |> Keyword.put(:resource,
                                                   type: {:spark, Ash.Resource},
                                                   doc:
                                                     "The resource that the route's action is defined on"
                                                 )
                                           }
                                         end)

  defmodule BaseRoute do
    @moduledoc "Introspection target for base routes in `AshJsonApi.Domain`"
    defstruct [:route, :routes, :resource]
  end

  @base_route %Spark.Dsl.Entity{
    name: :base_route,
    target: BaseRoute,
    describe: """
    Sets a prefix for a list of contained routes
    """,
    examples: [
      """
      base_route "/posts" do
        index :read
        get :read
      end

      base_route "/comments" do
        index :read
      end
      """
    ],
    args: [:route, {:optional, :resource}],
    schema: [
      route: [
        type: :string,
        required: true,
        doc: "The route prefix to use for contained routes"
      ],
      resource: [
        type: {:spark, Ash.Resource},
        required: false,
        doc: "The resource that the contained routes will use by default"
      ]
    ],
    entities: [
      routes: @route_entities_with_optional_resource
    ]
  }

  @routes @our_routes
          |> Map.update!(:schema, &Keyword.delete(&1, :base))
          |> Map.update!(:entities, &[@base_route | &1])

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
        doc: "The router that you created for this Domain. Used by test helpers to send requests"
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
    sections: [@open_api, @routes]
  }

  @verifiers [
    AshJsonApi.Domain.Verifiers.VerifyOpenApiGrouping,
    AshJsonApi.Domain.Verifiers.VerifyRelationships,
    AshJsonApi.Domain.Verifiers.VerifyActions,
    AshJsonApi.Domain.Verifiers.VerifyHasType,
    AshJsonApi.Domain.Verifiers.VerifyQueryParams
  ]

  @persisters [AshJsonApi.Domain.Persisters.DefineRouter]
  @transformers [AshJsonApi.Domain.Transformers.SetBaseRoutes]

  @sections [@json_api]

  @moduledoc """
  The entrypoint for adding JSON:API behavior to an Ash domain
  """

  use Spark.Dsl.Extension,
    sections: @sections,
    verifiers: @verifiers,
    persisters: @persisters,
    transformers: @transformers
end
