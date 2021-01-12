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
    primary?: [
      type: :boolean,
      default: false,
      doc:
        "Whether or not this is the route that should be linked to by default when rendering links to this type of route"
    ]
  ]

  @get %Ash.Dsl.Entity{
    name: :get,
    args: [:action],
    describe: "A GET route to retrieve a single record",
    examples: [
      "get :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.set_default!(:route, "/:id"),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.Get,
      action_type: :read,
      type: :get
    ]
  }

  @index %Ash.Dsl.Entity{
    name: :index,
    args: [:action],
    describe: "A GET route to retrieve a list of records",
    examples: [
      "index :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.set_default!(:route, "/")
      |> Keyword.put(:paginate?, type: :boolean, default: true),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.Index,
      action_type: :read,
      type: :index
    ]
  }

  @post %Ash.Dsl.Entity{
    name: :post,
    args: [:action],
    describe: "A POST route to create a record",
    examples: [
      "post :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.set_default!(:route, "/"),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :post,
      controller: AshJsonApi.Controllers.Post,
      action_type: :create,
      type: :post
    ]
  }

  @patch %Ash.Dsl.Entity{
    name: :patch,
    args: [:action],
    describe: "A PATCH route to update a record",
    examples: [
      "patch :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.set_default!(:route, "/:id"),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :patch,
      controller: AshJsonApi.Controllers.Patch,
      action_type: :update,
      type: :patch
    ]
  }

  @delete %Ash.Dsl.Entity{
    name: :delete,
    args: [:action],
    describe: "A DELETE route to destroy a record",
    examples: [
      "delete :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.set_default!(:route, "/:id"),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :delete,
      controller: AshJsonApi.Controllers.Delete,
      action_type: :destroy,
      type: :delete
    ]
  }

  @related %Ash.Dsl.Entity{
    name: :related,
    args: [:relationship, :action],
    describe: "A GET route to read the related resources of a relationship",
    examples: [
      "related :comments, :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.make_optional!(:route)
      |> Ash.OptionsHelpers.append_doc!(:route, "Defaults to /:id/[relationship_name]")
      |> Keyword.put(:relationship,
        type: :atom,
        required: true
      ),
    transform: {__MODULE__, :set_related_route, []},
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.GetRelated
    ]
  }

  @relationship %Ash.Dsl.Entity{
    name: :relationship,
    args: [:relationship, :action],
    describe: "A READ route to read the relationship, returns resource identifiers.",
    examples: [
      "relationship :comments, :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.make_optional!(:route)
      |> Ash.OptionsHelpers.append_doc!(
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
      controller: AshJsonApi.Controllers.GetRelationship
    ]
  }

  @post_to_relationship %Ash.Dsl.Entity{
    name: :post_to_relationship,
    args: [:relationship, :action],
    describe: "A POST route to create related entities using resource identifiers",
    examples: [
      "post_to_relationship :comments, :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.make_optional!(:route)
      |> Ash.OptionsHelpers.append_doc!(
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
      method: :post,
      type: :post_to_relationship,
      controller: AshJsonApi.Controllers.PostToRelationship
    ]
  }

  @patch_relationship %Ash.Dsl.Entity{
    name: :patch_relationship,
    args: [:relationship, :action],
    describe: "A PATCH route to update a relationship using resource identifiers",
    examples: [
      "patch_relationship :comments, :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.make_optional!(:route)
      |> Ash.OptionsHelpers.append_doc!(
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
      method: :patch,
      type: :patch_relationship,
      controller: AshJsonApi.Controllers.PatchRelationship
    ]
  }

  @delete_from_relationship %Ash.Dsl.Entity{
    name: :delete_from_relationship,
    args: [:relationship, :action],
    describe: "A DELETE route to remove related entities using resource identifiers",
    examples: [
      "delete_from_relationship :comments, :default"
    ],
    schema:
      @route_schema
      |> Ash.OptionsHelpers.make_optional!(:route)
      |> Ash.OptionsHelpers.append_doc!(
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
      method: :delete,
      type: :delete_from_relationship,
      controller: AshJsonApi.Controllers.DeleteFromRelationship
    ]
  }

  @routes %Ash.Dsl.Section{
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
        base_route "/posts"

        get :default
        get :me, route: "/me"
        index :default
        post :confirm_name, route: "/confirm_name"
        patch :default
        related :comments, :default
        relationship :comments, :default
        post_to_relationship :comments, :default
        patch_relationship :comments, :default
        delete_from_relationship :comments, :default
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

  @primary_key %Ash.Dsl.Section{
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
        type: {:custom, Ash.OptionsHelpers, :list_of_atoms, []},
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

  @json_api %Ash.Dsl.Section{
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
          base_route "/posts"

          get :default
          get :me, route: "/me"
          index :default
          post :confirm_name, route: "/confirm_name"
          patch :default
          related :comments, :default
          relationship :comments, :default
          post_to_relationship :comments, :default
          patch_relationship :comments, :default
          delete_from_relationship :comments, :default
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
      ]
    ]
  }

  @transformers [
    AshJsonApi.Resource.Transformers.PrependRoutePrefix,
    AshJsonApi.Resource.Transformers.ValidateNoOverlappingRoutes,
    AshJsonApi.Resource.Transformers.RequirePrimaryKey
  ]

  @sections [@json_api]

  @moduledoc """
  The entrypoint for adding JSON:API behavior to a resource"

  # Table of Contents
  #{Ash.Dsl.Extension.doc_index(@sections)}

  #{Ash.Dsl.Extension.doc(@sections)}
  """

  require Ash.Dsl.Extension

  use Ash.Dsl.Extension, sections: @sections, transformers: @transformers

  def type(resource) do
    Extension.get_opt(resource, [:json_api], :type, nil, false)
  end

  def includes(resource) do
    Extension.get_opt(resource, [:json_api], :includes, [], false)
  end

  def base_route(resource) do
    Extension.get_opt(resource, [:json_api, :routes], :base, nil, false)
  end

  def encode_primary_key(%resource{} = record) do
    case primary_key_fields(resource) do
      [] ->
        # Expect resource to have only 1 primary key if :primary_key section is not used
        [key] = Ash.Resource.primary_key(resource)
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

  def primary_key_fields(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :keys, [], false)
  end

  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :delimiter, [], false)
  end

  def routes(resource) do
    Extension.get_entities(resource, [:json_api, :routes])
  end

  def route(resource, criteria \\ %{}) do
    resource
    |> routes()
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
end
