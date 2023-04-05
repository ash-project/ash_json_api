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
      |> Spark.OptionsHelpers.set_default!(:route, "/:id"),
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
      |> Spark.OptionsHelpers.set_default!(:route, "/")
      |> Keyword.put(:paginate?, type: :boolean, default: true),
    target: AshJsonApi.Resource.Route,
    auto_set_fields: [
      method: :get,
      controller: AshJsonApi.Controllers.Index,
      action_type: :read,
      type: :index
    ]
  }

  @relationship_arguments_doc """
  A list of arguments that can be edited in the `data.relationships` input.

  This is primarily useful for those who want to keep their relationship changes in compliance with the `JSON:API` spec.
  If you are not focused on building a fully compliant JSON:API, it is likely far simpler to simply accept arguments
  in the `attributes` key and ignore the `data.relationships` input.

  If the argument's type is `{:array, _}`, a list of data will be expected. Otherwise, it will expect a single item.

  For example:

  ```elixir
  # On a tweets resource

  # With a patch route that references the `authors` argument
  json_api do
    routes do
      patch :update, relationship_arguments: [:authors]
    end
  end

  # And an argument by that name in the action
  actions do
    update :update do
      argument :authors, {:array, :map}, allow_nil?: false

      change manage_relationship(:authors, type: :append_and_remove) # Use the authors argument to allow changing the related authors on update
    end
  end
  ```

  You can then send the value for `authors` in the relationships key, e.g
  ```json
  {
    data: {
      attributes: {
        ...
      },
      relationships: {
        authors: {
          data: [
            {type: "author", id: 1}, // the `type` key is removed when the value is placed into the action, so this input would be `%{"id" => 1}` (`type` is required by `JSON:API` specification)
            {type: "author", id: 2, meta: {arbitrary: 1, keys: 2}}, <- `meta` is JSON:API spec freeform data, so this input would be `%{"id" => 2, "arbitrary" => 1, "keys" => 2}`
          ]
        }
      }
    }
  }
  ```

  If you do not include `:authors` in the `relationship_arguments` key, you would supply its value in `attributes`, e.g:

  ```elixir
  {
    data: {
      attributes: {
        authors: {
          {id: 1},
          {id: 2, arbitrary: 1, keys: 2},
        }
      }
    }
  }
  ```

  Non-map argument types, e.g `argument :author, :integer` (expecting an author id) work with `manage_relationship`, but not with
  JSON:API, because it expects `{"type": _type, "id" => id}` for relationship values. To support non-map arguments in `relationship_arguments`,
  instead of `:author`, use `{:id, :author}`. This works for `{:array, _}` type arguments as well, so the value would be a list of ids.
  """

  @post %Spark.Dsl.Entity{
    name: :post,
    args: [:action],
    describe: "A POST route to create a record",
    examples: [
      "post :create"
    ],
    schema:
      @route_schema
      |> Spark.OptionsHelpers.set_default!(:route, "/")
      |> Keyword.merge(
        relationship_arguments: [type: :any, doc: @relationship_arguments_doc, default: []],
        upsert?: [
          type: :boolean,
          default: false,
          doc: "Whether or not to use the `upsert?: true` option when calling `YourApi.create/2`."
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
      |> Spark.OptionsHelpers.set_default!(:route, "/:id")
      |> Keyword.put(:read_action,
        type: :atom,
        default: nil,
        doc: "The read action to use to look the record up before updating"
      )
      |> Keyword.put(:relationship_arguments,
        type: :any,
        doc: @relationship_arguments_doc,
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
      |> Spark.OptionsHelpers.set_default!(:route, "/:id")
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
      |> Spark.OptionsHelpers.make_optional!(:route)
      |> Spark.OptionsHelpers.append_doc!(:route, "Defaults to /:id/[relationship_name]")
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
      |> Spark.OptionsHelpers.make_optional!(:route)
      |> Spark.OptionsHelpers.append_doc!(
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
      |> Spark.OptionsHelpers.make_optional!(:route)
      |> Spark.OptionsHelpers.append_doc!(
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
      |> Spark.OptionsHelpers.make_optional!(:route)
      |> Spark.OptionsHelpers.append_doc!(
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
      |> Spark.OptionsHelpers.make_optional!(:route)
      |> Spark.OptionsHelpers.append_doc!(
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
        type: {:custom, Spark.OptionsHelpers, :list_of_atoms, []},
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
  #{Spark.Dsl.Extension.doc_index(@sections)}

  #{Spark.Dsl.Extension.doc(@sections)}
  """

  use Spark.Dsl.Extension, sections: @sections, transformers: @transformers

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
  defdelegate routes(resource), to: AshJsonApi.Resource.Info

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
