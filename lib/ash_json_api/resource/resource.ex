defmodule AshJsonApi.Resource do
  @route_schema [
    route: [
      type: :string,
      required: true,
      doc: "The path of the route"
    ],
    action: [
      type: :atom,
      required: true,
      doc: "The action to call when this route is hit"
    ],
    default_fields: [
      type: {:list, :atom},
      required: false,
      doc: "A list of fields to be shown in the attributes of the called route"
    ],
    primary?: [
      type: :boolean,
      default: false,
      doc:
        "Whether or not this is the route that should be linked to by default when rendering links to this type of route"
    ],
    metadata: [
      type: {:fun, 3},
      required: false,
      doc: "A function to generate arbitrary top-level metadata for the JSON:API response"
    ],
    name: [
      type: :string,
      required: false,
      doc:
        "A globally unique name for this route, to be used when generating docs and open api specifications"
    ],
    derive_sort?: [
      type: :boolean,
      doc:
        "Whether or not to derive a sort parameter based on the sortable fields of the resource",
      default: true
    ],
    derive_filter?: [
      type: :boolean,
      doc:
        "Whether or not to derive a filter parameter based on the sortable fields of the resource",
      default: true
    ]
  ]

  @get %Spark.Dsl.Entity{
    name: :get,
    args: [:action],
    describe: "A GET route to retrieve a single record",
    examples: [
      "get :read"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.set_default!(:route, "/:id"),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.Get,
      action_type: :read,
      type: :get
    ]
  }

  @index %Spark.Dsl.Entity{
    name: :index,
    args: [:action],
    describe: "A GET route to retrieve a list of records",
    examples: [
      "index :read"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.set_default!(:route, "/")
      |> Keyword.put(:paginate?, type: :boolean, default: true),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.Index,
      action_type: :read,
      type: :index
    ]
  }

  @post %Spark.Dsl.Entity{
    name: :post,
    args: [:action],
    describe: "A POST route to create a record",
    examples: [
      "post :create"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.set_default!(:route, "/")
      |> Keyword.merge(
        relationship_arguments: [
          type: {:list, {:or, [:atom, {:tuple, [{:literal, :id}, :atom]}]}},
          doc:
            "Arguments to be used to edit relationships. See the [relationships guide](/documentation/topics/relationships.md) for more.",
          default: []
        ],
        upsert?: [
          type: :boolean,
          default: false,
          doc: "Whether or not to use the `upsert?: true` option when calling `Ash.create/2`."
        ],
        upsert_identity: [
          type: :atom,
          default: false,
          doc: "Which identity to use for the upsert"
        ]
      ),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :post,
      controller: AshJsonApi.Controllers.Post,
      action_type: :create,
      type: :post
    ]
  }

  @patch %Spark.Dsl.Entity{
    name: :patch,
    args: [:action],
    describe: "A PATCH route to update a record",
    examples: [
      "patch :update"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.set_default!(:route, "/:id")
      |> Keyword.put(:read_action,
        type: :atom,
        default: nil,
        doc: "The read action to use to look the record up before updating"
      )
      |> Keyword.put(:relationship_arguments,
        type: :any,
        doc:
          "Arguments to be used to edit relationships. See the [relationships guide](/documentation/topics/relationships.md) for more.",
        default: []
      ),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :patch,
      controller: AshJsonApi.Controllers.Patch,
      action_type: :update,
      type: :patch
    ]
  }

  @delete %Spark.Dsl.Entity{
    name: :delete,
    args: [:action],
    describe: "A DELETE route to destroy a record",
    examples: [
      "delete :destroy"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.set_default!(:route, "/:id")
      |> Keyword.put(:read_action,
        type: :atom,
        default: nil,
        doc: "The read action to use to look the record up before updating"
      ),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :delete,
      controller: AshJsonApi.Controllers.Delete,
      action_type: :destroy,
      type: :delete
    ]
  }

  @related %Spark.Dsl.Entity{
    name: :related,
    args: [:relationship, :action],
    describe: "A GET route to read the related resources of a relationship",
    examples: [
      "related :comments, :read"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.make_optional!(:route)
      |> Spark.Options.Helpers.append_doc!(:route, "Defaults to /:id/[relationship_name]")
      |> Keyword.put(:relationship,
        type: :atom,
        required: true
      ),
    transform: {__MODULE__, :set_related_route, []},
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.GetRelated,
      action_type: :get_related
    ]
  }

  @relationship %Spark.Dsl.Entity{
    name: :relationship,
    args: [:relationship, :action],
    describe: "A READ route to read the relationship, returns resource identifiers.",
    examples: [
      "relationship :comments, :read"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.make_optional!(:route)
      |> Spark.Options.Helpers.append_doc!(
        :route,
        " Defaults to /:id/relationships/[relationship_name]"
      )
      |> Keyword.put(:relationship,
        type: :atom,
        required: true
      ),
    transform: {__MODULE__, :set_relationship_route, []},
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.GetRelationship,
      action_type: :relationship
    ]
  }

  @post_to_relationship %Spark.Dsl.Entity{
    name: :post_to_relationship,
    args: [:relationship],
    describe: "A POST route to create related entities using resource identifiers",
    examples: [
      "post_to_relationship :comments"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.make_optional!(:route)
      |> Spark.Options.Helpers.append_doc!(
        :route,
        " Defaults to /:id/relationships/[relationship_name]"
      )
      |> Keyword.put(:relationship,
        type: :atom,
        required: true
      )
      |> Keyword.delete(:action),
    transform: {__MODULE__, :set_relationship_route, []},
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :post,
      type: :post_to_relationship,
      controller: AshJsonApi.Controllers.PostToRelationship
    ]
  }

  @patch_relationship %Spark.Dsl.Entity{
    name: :patch_relationship,
    args: [:relationship],
    describe: "A PATCH route to update a relationship using resource identifiers",
    examples: [
      "patch_relationship :comments"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.make_optional!(:route)
      |> Spark.Options.Helpers.append_doc!(
        :route,
        " Defaults to /:id/relationships/[relationship_name]"
      )
      |> Keyword.put(:relationship,
        type: :atom,
        required: true
      )
      |> Keyword.delete(:action),
    transform: {__MODULE__, :set_relationship_route, []},
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :patch,
      type: :patch_relationship,
      controller: AshJsonApi.Controllers.PatchRelationship
    ]
  }

  @delete_from_relationship %Spark.Dsl.Entity{
    name: :delete_from_relationship,
    args: [:relationship],
    describe: "A DELETE route to remove related entities using resource identifiers",
    examples: [
      "delete_from_relationship :comments"
    ],
    schema:
      @route_schema
      |> Spark.Options.Helpers.make_optional!(:route)
      |> Spark.Options.Helpers.append_doc!(
        :route,
        " Defaults to /:id/relationships/[relationship_name]"
      )
      |> Keyword.put(:relationship,
        type: :atom,
        required: true
      )
      |> Keyword.delete(:action),
    transform: {__MODULE__, :set_relationship_route, []},
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :delete,
      type: :delete_from_relationship,
      controller: AshJsonApi.Controllers.DeleteFromRelationship
    ]
  }

  @routes %Spark.Dsl.Section{
    name: :routes,
    describe: "Configure the routes that will be exposed via the JSON:API",
    schema: [
      base: [
        type: :string,
        required: true,
        doc: "The base route for the resource, e.g `\"/users\"`"
      ]
    ],
    examples: [
      """
      routes do
        base "/posts"

        get :read
        get :me, route: "/me"
        index :read
        post :confirm_name, route: "/confirm_name"
        patch :update
        related :comments, :read
        relationship :comments, :read
        post_to_relationship :comments
        patch_relationship :comments
        delete_from_relationship :comments
      end
      """
    ],
    entities: [
      @get,
      @index,
      @post,
      @patch,
      @delete,
      @related,
      @relationship,
      @post_to_relationship,
      @patch_relationship,
      @delete_from_relationship
    ]
  }

  @doc false
  def routes, do: @routes

  @primary_key %Spark.Dsl.Section{
    name: :primary_key,
    describe: "Encode the id of the JSON API response from selected attributes of a resource",
    examples: [
      """
      primary_key do
        keys [:first_name, :last_name]
        delimiter "~"
      end
      """
    ],
    schema: [
      keys: [
        type: {:wrap_list, :atom},
        doc: "the list of attributes to encode JSON API primary key",
        required: true
      ],
      delimiter: [
        type: :string,
        default: "-",
        required: false,
        doc: "The delimiter to concatenate the primary key values. Default to be '-'"
      ]
    ]
  }

  @json_api %Spark.Dsl.Section{
    name: :json_api,
    sections: [@routes, @primary_key],
    describe: "Configure the resource's behavior in the JSON:API",
    examples: [
      """
      json_api do
        type "post"
        includes [
          friends: [
            :comments
          ],
          comments: []
        ]

        routes do
          base "/posts"

          get :read
          get :me, route: "/me"
          index :read
          post :confirm_name, route: "/confirm_name"
          patch :update
          related :comments, :read
          relationship :comments, :read
          post_to_relationship :comments
          patch_relationship :comments
          delete_from_relationship :comments
        end
      end
      """
    ],
    schema: [
      type: [
        type: :string,
        doc: "The resource identifier type of this resource in JSON:API",
        required: true
      ],
      includes: [
        type: :any,
        default: [],
        doc: "A keyword list of all paths that are includable from this resource"
      ],
      include_nil_values?: [
        type: :any,
        default: nil,
        doc: "Whether or not to include properties for values that are nil in the JSON output"
      ],
      default_fields: [
        type: {:list, :atom},
        doc:
          "The fields to include in the object if the `fields` query parameter does not specify. Defaults to all public"
      ],
      derive_sort?: [
        type: :boolean,
        doc:
          "Whether or not to derive a sort parameter based on the sortable fields of the resource",
        default: true
      ],
      derive_filter?: [
        type: :boolean,
        doc:
          "Whether or not to derive a filter parameter based on the sortable fields of the resource",
        default: true
      ]
    ]
  }

  @transformers [
    AshJsonApi.Resource.Transformers.PrependRoutePrefix,
    AshJsonApi.Resource.Transformers.ValidateNoOverlappingRoutes,
    AshJsonApi.Resource.Transformers.RequirePrimaryKey
  ]

  @persisters [
    AshJsonApi.Resource.Persisters.DefineRouter
  ]

  @verifiers [
    AshJsonApi.Resource.Verifiers.VerifyRelationships,
    AshJsonApi.Resource.Verifiers.VerifyIncludes
  ]

  @sections [@json_api]

  @moduledoc """
  The entrypoint for adding JSON:API behavior to a resource"
  """

  use Spark.Dsl.Extension,
    sections: @sections,
    transformers: @transformers,
    persisters: @persisters,
    verifiers: @verifiers

  @deprecated "See AshJsonApi.Resource.Info.type/1"
  defdelegate type(resource), to: AshJsonApi.Resource.Info

  @deprecated "See AshJsonApi.Resource.Info.includes/1"
  defdelegate includes(resource), to: AshJsonApi.Resource.Info

  @deprecated "See AshJsonApi.Resource.Info.base_route/1"
  defdelegate base_route(resource), to: AshJsonApi.Resource.Info

  @deprecated "See AshJsonApi.Resource.Info.primary_key_fields/1"
  defdelegate primary_key_fields(resource), to: AshJsonApi.Resource.Info

  @deprecated "See AshJsonApi.Resource.Info.primary_key_delimiter/1"
  defdelegate primary_key_delimiter(resource), to: AshJsonApi.Resource.Info

  @deprecated "See AshJsonApi.Resource.Info.routes/1"
  defdelegate routes(resource, domains), to: AshJsonApi.Resource.Info

  def encode_primary_key(%resource{} = record) do
    case primary_key_fields(resource) do
      [] ->
        # Expect resource to have only 1 primary key if :primary_key section is not used
        [key] = Ash.Resource.Info.primary_key(resource)
        Map.get(record, key)

      keys ->
        delimiter = primary_key_delimiter(resource)

        [_ | concatenated_keys] =
          keys
          |> Enum.reverse()
          |> Enum.reduce([], fn key, acc -> [delimiter, to_string(Map.get(record, key)), acc] end)

        IO.iodata_to_binary(concatenated_keys)
    end
  end

  def route(resource, domains, criteria \\ %{}) do
    resource
    |> routes(domains)
    |> Enum.find(fn route ->
      Map.take(route, Map.keys(criteria)) == criteria
    end)
  end

  @doc false
  def set_related_route(%{route: nil, relationship: relationship} = route) do
    {:ok, %{route | route: ":id/#{relationship}"}}
  end

  def set_related_route(route), do: {:ok, route}

  @doc false
  def set_relationship_route(%{route: nil, relationship: relationship} = route) do
    {:ok, %{route | route: ":id/relationships/#{relationship}"}}
  end

  def set_relationship_route(route), do: {:ok, route}

  @doc false
  def validate_fields(fields) when is_list(fields) do
    if Enum.all?(fields, &is_atom/1) do
      {:ok, fields}
    else
      {:error, "Invalid fields"}
    end
  end

  def only_primary_key?(resource, field) do
    resource
    |> Ash.Resource.Info.primary_key()
    |> case do
      [^field] -> true
      _ -> false
    end
  end
end
