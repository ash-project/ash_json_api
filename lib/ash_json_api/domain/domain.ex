# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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
    defstruct [:route, :routes, :resource, :__spark_metadata__]
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
    recursive_as: :routes,
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
      serve_schema?: "Use the `json_schema` option to `use AshJsonApi.Router` instead.",
      router:
        "Specify the router option in your calls to test helpers, or configure it via `config :your_app, YourDomain, test_router: YourRouter` in config/test.exs."
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

  if Code.ensure_loaded?(Igniter) do
    def install(igniter, module, Ash.Domain, _path, _argv) do
      igniter
      |> Spark.Igniter.add_extension(
        module,
        Ash.Domain,
        :extensions,
        AshJsonApi.Domain
      )
      |> add_to_ash_json_api_router(module)
    end

    defp add_to_ash_json_api_router(igniter, domain) do
      case AshJsonApi.Igniter.find_ash_json_api_router(igniter, domain) do
        {:ok, igniter, _} ->
          igniter

        {:error, igniter, []} ->
          AshJsonApi.Igniter.setup_ash_json_api_router(igniter)

        {:error, igniter, all_ash_json_api_routers} ->
          ash_json_api_router =
            case all_ash_json_api_routers do
              [ash_json_api_router] ->
                ash_json_api_router

              ash_json_api_routers ->
                Owl.IO.select(
                  ash_json_api_routers,
                  label: "Multiple AshJsonApi.Router modules found. Please select one to use:",
                  render_as: &inspect/1
                )
            end

          Igniter.Project.Module.find_and_update_module!(
            igniter,
            ash_json_api_router,
            fn zipper ->
              with {:ok, zipper} <- Igniter.Code.Module.move_to_use(zipper, AshJsonApi.Router),
                   {:ok, zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 1),
                   {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, :domains),
                   {:has_domain?, false} <- {:has_domain?, list_has_domain?(zipper, domain)},
                   {:ok, zipper} <-
                     Igniter.Code.List.append_to_list(
                       zipper,
                       domain
                     ) do
                {:ok, zipper}
              else
                {:has_domain?, true} ->
                  {:ok, zipper}

                _ ->
                  {:warning,
                   """
                   Could not add #{inspect(domain)} to the list of domains in #{inspect(ash_json_api_router)}.

                   Please make that change manually.
                   """}
              end
            end
          )
      end
    end

    defp list_has_domain?(zipper, domain) do
      list_has_literal_domain?(zipper, domain) || list_has_concat_domain?(zipper, domain)
    end

    defp list_has_literal_domain?(zipper, domain) do
      !!Igniter.Code.List.find_list_item_index(zipper, fn zipper ->
        Igniter.Code.Common.nodes_equal?(zipper, domain)
      end)
    end

    defp list_has_concat_domain?(zipper, domain) do
      !!Igniter.Code.List.find_list_item_index(zipper, fn zipper ->
        with true <- Igniter.Code.Function.function_call?(zipper, {Module, :concat}, 1),
             {:ok, zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 0),
             true <- Igniter.Code.List.list?(zipper) do
          Igniter.Code.Common.nodes_equal?(
            zipper,
            [inspect(domain)]
          )
        else
          _ ->
            false
        end
      end)
    end
  end
end
