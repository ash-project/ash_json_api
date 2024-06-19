defmodule Test.Acceptance.OpenApiTest do
  use ExUnit.Case, async: true
  alias OpenApiSpex.{OpenApi, Schema}

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.OpenApiTest.Blogs,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("author")
      includes posts: [:tags]

      routes do
        base("/authors")
        get(:read)
        index(:read, name: "listAuthors")
        patch(:update)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, public?: true)
    end

    relationships do
      has_many(:posts, Test.Acceptance.OpenApiTest.Post,
        destination_attribute: :author_id,
        public?: true
      )
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.OpenApiTest.Blogs,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("post")
      includes :tags

      routes do
        base("/posts")
        get(:read)
        index(:read)
        post(:create, relationship_arguments: [{:id, :author}])
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :name, :hidden])
        argument(:author, :uuid)

        change(manage_relationship(:author, type: :append_and_remove))
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)

      attribute(:name, :string,
        allow_nil?: false,
        description: "description of attribute :name",
        public?: true
      )

      attribute(:hidden, :string, description: "description of attribute :hidden", public?: true)

      attribute(:email, :string,
        allow_nil?: true,
        public?: true,
        constraints: [
          match: ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
        ]
      )
    end

    calculations do
      calculate(:name_twice, :string, concat([:name, :name], "-"), public?: true)
    end

    aggregates do
      count(:count_of_tags, :tags, public?: true)
    end

    relationships do
      belongs_to(:author, Test.Acceptance.OpenApiTest.Author, allow_nil?: false, public?: true)

      has_many(:tags, Test.Acceptance.OpenApiTest.Tag,
        destination_attribute: :post_id,
        public?: true
      )
    end
  end

  defmodule Tag do
    use Ash.Resource,
      domain: Test.Acceptance.OpenApiTest.Blogs,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    actions do
      default_accept(:*)
      defaults([:read, :create, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id, writable?: true, public?: true)
      attribute(:name, :string, allow_nil?: false, public?: true, public?: true)
    end

    relationships do
      belongs_to(:post, Test.Acceptance.OpenApiTest.Post, allow_nil?: false, public?: true)
    end
  end

  defmodule Blogs do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router(Test.Acceptance.OpenApiTest.Router)
      log_errors?(false)
    end

    resources do
      resource(Post)
      resource(Author)
      resource(Tag)
    end
  end

  def modify(spec, _conn, _opts) do
    %{spec | info: %{spec.info | title: "foobar"}}
  end

  setup do
    api_spec =
      AshJsonApi.Controllers.OpenApi.spec(%{private: %{}},
        domains: [Blogs],
        modify: {__MODULE__, :modify, []}
      )

    %{open_api_spec: api_spec}
  end

  test "modify option is honored", %{open_api_spec: api_spec} do
    assert api_spec.info.title == "foobar"
  end

  test "resources without a json_api are not included in the schema", %{open_api_spec: api_spec} do
    schema_keys = api_spec.components.schemas |> Map.keys()
    assert "tags" not in schema_keys
  end

  test "API routes are mapped to OpenAPI Operations", %{open_api_spec: %OpenApi{} = api_spec} do
    assert map_size(api_spec.paths) == 4

    assert %{"/authors" => _, "/authors/{id}" => _, "/posts" => _, "/posts/{id}" => _} =
             api_spec.paths

    assert %OpenApiSpex.Operation{} = api_spec.paths["/authors"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["/authors/{id}"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["/authors/{id}"].patch
    assert nil == api_spec.paths["/authors"].post

    assert %OpenApiSpex.Operation{} = api_spec.paths["/posts"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["/posts/{id}"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["/posts"].post
    assert nil == api_spec.paths["/posts/{id}"].patch
  end

  test "API routes use `name` as operationId", %{
    open_api_spec: %OpenApi{} = api_spec
  } do
    assert %OpenApiSpex.Operation{operationId: "listAuthors"} = api_spec.paths["/authors"].get
    assert %OpenApiSpex.Operation{operationId: nil} = api_spec.paths["/authors/{id}"].get
  end

  test "API routes use `name` in default descriptions", %{
    open_api_spec: %OpenApi{} = api_spec
  } do
    assert %OpenApiSpex.Operation{description: "listAuthors operation on author resource"} =
             api_spec.paths["/authors"].get

    assert %OpenApiSpex.Operation{description: "/authors/:id operation on author resource"} =
             api_spec.paths["/authors/{id}"].get
  end

  describe "Index route" do
    test "filter parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      %OpenApiSpex.Parameter{} = filter = operation.parameters |> Enum.find(&(&1.name == :filter))
      assert filter.in == :query
      assert filter.required == false
      assert filter.style == :deepObject
      %Schema{} = schema = filter.schema
      assert schema.type == :object

      assert schema.properties == %{
               id: %Schema{
                 anyOf: [
                   %Schema{type: :object, additionalProperties: true},
                   %Schema{type: :string}
                 ]
               },
               author: %Schema{type: :object, additionalProperties: true},
               email: %Schema{
                 anyOf: [
                   %Schema{type: :object, additionalProperties: true},
                   %Schema{type: :string}
                 ]
               },
               hidden: %Schema{
                 anyOf: [
                   %Schema{type: :object, additionalProperties: true},
                   %Schema{type: :string}
                 ],
                 description: "description of attribute :hidden"
               },
               name: %Schema{
                 anyOf: [
                   %Schema{type: :object, additionalProperties: true},
                   %Schema{type: :string}
                 ],
                 description: "description of attribute :name"
               },
               tags: %Schema{type: :object, additionalProperties: true},
               author_id: %OpenApiSpex.Schema{
                 anyOf: [
                   %OpenApiSpex.Schema{type: :object, additionalProperties: true},
                   %OpenApiSpex.Schema{type: :string}
                 ]
               },
               count_of_tags: %Schema{
                 anyOf: [
                   %Schema{type: :object, additionalProperties: true},
                   %Schema{type: :string}
                 ]
               }
             }

      assert schema.required == nil
    end

    test "sort parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      %OpenApiSpex.Parameter{} = sort = operation.parameters |> Enum.find(&(&1.name == :sort))
      assert sort.in == :query
      assert sort.required == false
      assert sort.style == :form
      assert !sort.explode
      %Schema{} = schema = sort.schema
      assert schema.type == :array
      assert schema.items.type == :string

      assert schema.items.enum == [
               "id",
               "-id",
               "name",
               "-name",
               "hidden",
               "-hidden",
               "email",
               "-email",
               "author_id",
               "-author_id"
             ]
    end

    test "page parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      %OpenApiSpex.Parameter{} = page = operation.parameters |> Enum.find(&(&1.name == :page))
      assert page.in == :query
      assert page.required == false
      assert page.style == :deepObject
      %Schema{} = schema = page.schema
      assert schema.type == :object

      assert schema.properties == %{
               limit: %Schema{type: :integer, minimum: 1},
               offset: %Schema{type: :integer, minimum: 0}
             }
    end

    test "include parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get

      %OpenApiSpex.Parameter{} =
        include = operation.parameters |> Enum.find(&(&1.name == :include))

      assert include.in == :query
      assert include.required == false
      assert include.style == :form
      assert include.explode == false
      %Schema{} = schema = include.schema
      assert schema.type == :array
      assert schema.items.type == :string
      assert schema.items.pattern |> is_struct(Regex)
      assert Regex.match?(schema.items.pattern, "author")
      refute Regex.match?(schema.items.pattern, "000")
      refute Regex.match?(schema.items.pattern, "a b c")
    end

    test "fields parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      %OpenApiSpex.Parameter{} = fields = operation.parameters |> Enum.find(&(&1.name == :fields))
      assert fields.in == :query
      assert fields.required == false
      assert fields.style == :deepObject
      %Schema{} = schema = fields.schema
      assert schema.type == :object
      assert schema.additionalProperties
      assert schema.properties.post.type == :string
      assert schema.properties.post.description =~ "field names for post"
    end

    test "Has no request body", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      refute operation.requestBody
    end

    test "Response body schema", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      response = operation.responses[200]
      schema = response.content["application/vnd.api+json"].schema
      assert schema.type == :object
      assert schema.properties.data.type == :array
      assert schema.properties.data.uniqueItems == true
      assert schema.properties.data.items."$ref" == "#/components/schemas/post"

      assert api_spec.components.schemas["post"] == %OpenApiSpex.Schema{
               additionalProperties: false,
               description: "A \"Resource object\" representing a post",
               properties: %{
                 attributes: %OpenApiSpex.Schema{
                   additionalProperties: false,
                   description: "An attributes object for a post",
                   properties: %{
                     email: %OpenApiSpex.Schema{
                       anyOf: [
                         %OpenApiSpex.Schema{type: :string},
                         %OpenApiSpex.Schema{type: :null}
                       ],
                       description: "Field included by default."
                     },
                     hidden: %OpenApiSpex.Schema{
                       anyOf: [
                         %OpenApiSpex.Schema{type: :string},
                         %OpenApiSpex.Schema{type: :null}
                       ],
                       description: "description of attribute :hidden. Field included by default."
                     },
                     name: %OpenApiSpex.Schema{
                       type: :string,
                       description: "description of attribute :name. Field included by default."
                     },
                     name_twice: %OpenApiSpex.Schema{
                       anyOf: [
                         %OpenApiSpex.Schema{type: :string},
                         %OpenApiSpex.Schema{type: :null}
                       ]
                     },
                     author_id: %OpenApiSpex.Schema{
                       type: :string,
                       format: "uuid",
                       description: "Field included by default."
                     },
                     count_of_tags: %OpenApiSpex.Schema{type: :integer}
                   },
                   type: :object
                 },
                 id: %{type: :string},
                 relationships: %OpenApiSpex.Schema{
                   additionalProperties: false,
                   description: "A relationships object for a post",
                   properties: %{
                     author: %OpenApiSpex.Schema{
                       properties: %{
                         data: %OpenApiSpex.Schema{
                           type: :array,
                           description: "An array of inputs for author",
                           items: %{
                             type: :object,
                             description: "Resource identifiers for author",
                             required: [:type, :id],
                             properties: %{
                               id: %OpenApiSpex.Schema{type: :string},
                               meta: %OpenApiSpex.Schema{
                                 type: :object,
                                 additionalProperties: true
                               },
                               type: %OpenApiSpex.Schema{type: :string}
                             }
                           },
                           uniqueItems: true
                         }
                       }
                     }
                   },
                   type: :object
                 },
                 type: %OpenApiSpex.Schema{type: :string}
               },
               required: [:type, :id],
               type: :object
             }
    end
  end

  describe "Get route" do
    test "id parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts/{id}"].get
      %OpenApiSpex.Parameter{} = filter = operation.parameters |> Enum.find(&(&1.name == "id"))
      assert filter.in == :path
      assert filter.required == true
      assert filter.style == nil
      %Schema{} = schema = filter.schema
      assert schema.type == :string
    end

    test "include parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts/{id}"].get

      %OpenApiSpex.Parameter{} =
        include = operation.parameters |> Enum.find(&(&1.name == :include))

      assert include.in == :query
      assert include.required == false
      assert include.style == :form
      assert include.explode == false
      %Schema{} = schema = include.schema
      assert schema.type == :array
      assert schema.items.type == :string
      assert schema.items.pattern |> is_struct(Regex)
      assert Regex.match?(schema.items.pattern, "author")
      refute Regex.match?(schema.items.pattern, "000")
      refute Regex.match?(schema.items.pattern, "a b c")
    end

    test "fields parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts/{id}"].get
      %OpenApiSpex.Parameter{} = fields = operation.parameters |> Enum.find(&(&1.name == :fields))
      assert fields.in == :query
      assert fields.required == false
      assert fields.style == :deepObject
      %Schema{} = schema = fields.schema
      assert schema.type == :object
      assert schema.additionalProperties
      assert schema.properties.post.type == :string
      assert schema.properties.post.description =~ "field names for post"
    end

    test "Has no request body", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts/{id}"].get
      refute operation.requestBody
    end

    test "Response body schema", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts/{id}"].get
      response = operation.responses[200]
      schema = response.content["application/vnd.api+json"].schema
      assert schema.properties.data."$ref" == "#/components/schemas/post"
      assert schema.properties.included.type == :array
      assert schema.properties.included.items.oneOf == []
    end

    test "Response body schema with includes", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/authors/{id}"].get
      response = operation.responses[200]
      schema = response.content["application/vnd.api+json"].schema
      assert schema.properties.data."$ref" == "#/components/schemas/author"

      assert schema.properties.included.items.oneOf == [
               %OpenApiSpex.Reference{"$ref": "#/components/schemas/post"}
             ]
    end
  end

  describe "Create route" do
    test "include parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].post

      %OpenApiSpex.Parameter{} =
        include = operation.parameters |> Enum.find(&(&1.name == :include))

      assert include.in == :query
      assert include.required == false
      assert include.style == :form
      assert include.explode == false
      %Schema{} = schema = include.schema
      assert schema.type == :array
      assert schema.items.type == :string
      assert schema.items.pattern |> is_struct(Regex)
      assert Regex.match?(schema.items.pattern, "author")
      refute Regex.match?(schema.items.pattern, "000")
      refute Regex.match?(schema.items.pattern, "a b c")
    end

    test "fields parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].post
      %OpenApiSpex.Parameter{} = fields = operation.parameters |> Enum.find(&(&1.name == :fields))
      assert fields.in == :query
      assert fields.required == false
      assert fields.style == :deepObject
      %Schema{} = schema = fields.schema
      assert schema.type == :object
      assert schema.additionalProperties
      assert schema.properties.post.type == :string
      assert schema.properties.post.description =~ "field names for post"
    end

    test "Request body schema", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].post
      %OpenApiSpex.RequestBody{} = body = operation.requestBody
      schema = body.content["application/vnd.api+json"].schema
      assert schema.properties.data.type == :object
      assert schema.properties.data.properties.attributes.required == [:name]
      assert schema.properties.data.properties.attributes.type == :object
    end

    test "Response body schema", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].post
      response = operation.responses[200]
      schema = response.content["application/vnd.api+json"].schema
      assert schema.properties.data."$ref" == "#/components/schemas/post"
    end
  end
end
