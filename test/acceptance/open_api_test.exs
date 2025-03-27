defmodule Test.Acceptance.OpenApiTest do
  use ExUnit.Case, async: true

  import Plug.Test
  alias OpenApiSpex.{OpenApi, Schema}

  defmodule Bio do
    use Ash.Resource,
      data_layer: :embedded

    attributes do
      attribute(:history, :string, public?: true)
    end
  end

  defmodule Foo do
    use Ash.Resource, domain: nil, extensions: AshJsonApi.Resource

    json_api do
      type "foo"
    end

    resource do
      require_primary_key?(false)
    end

    attributes do
      attribute(:foo, :string, public?: true)
    end
  end

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.OpenApiTest.Blogs,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    resource do
      description("This is an author!")
    end

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
        index(:read, derive_filter?: false, derive_sort?: false, route: "/no_filter")
        patch(:update)
        route :post, "/say_hello/:to", :say_hello
        route :post, "/trigger_job", :trigger_job, query_params: [:job_id]
        route(:get, "returns_map", :returns_map)
        route(:get, "/get_foo", :get_foo)
        post_to_relationship :posts
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])

      action :say_hello, :string do
        argument(:to, :string, allow_nil?: false)
        argument(:from, :string, allow_nil?: false)

        run(fn input, _ ->
          {:ok, "Hello, #{input.arguments.to}! From: #{input.arguments.from}"}
        end)
      end

      action :get_foo, :struct do
        constraints(instance_of: Foo)
        argument(:bio, :struct, allow_nil?: false, constraints: [instance_of: Bio])

        run(fn input, _ ->
          {:ok, %Foo{foo: "bar"}}
        end)
      end

      action :trigger_job do
        argument(:job_id, :string)

        run(fn _input, _ ->
          :ok
        end)
      end

      action :returns_map, :map do
        constraints(fields: [a: [type: :integer], b: [type: :string, allow_nil?: false]])

        run(fn _input, _ ->
          {:ok, %{b: "foo"}}
        end)
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, public?: true)
      attribute(:bio, Bio, public?: true)
    end

    relationships do
      has_many(:posts, Test.Acceptance.OpenApiTest.Post,
        destination_attribute: :author_id,
        public?: true
      )
    end
  end

  defmodule AuthorNoFilter do
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
      type("author-no-filter")
      derive_filter? false

      routes do
        base("/authors_no_filter")
        index(:read, name: "listAuthorsNoFilter")
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
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Post)
      resource(Author)
      resource(Tag)
      resource(AuthorNoFilter)
    end
  end

  def modify_open_api(spec, _conn, _opts) do
    %{spec | info: %{spec.info | title: "foobar"}}
  end

  setup do
    api_spec =
      AshJsonApi.Controllers.OpenApi.spec(%{private: %{}},
        domains: [Blogs],
        modify_open_api: {__MODULE__, :modify_open_api, []}
      )

    %{open_api_spec: api_spec}
  end

  test "spec can be fetched from the controller", %{open_api_spec: api_spec} do
    assert :get
           |> conn("/open_api")
           |> AshJsonApi.Controllers.OpenApi.call(
             domains: [Blogs],
             modify_open_api: {__MODULE__, :modify_open_api, []}
           )
           |> sent_resp()
           |> elem(2)
           |> Jason.decode!()
           |> Kernel.==(Jason.decode!(Jason.encode!(api_spec)))
  end

  test "modify option is honored", %{open_api_spec: api_spec} do
    assert api_spec.info.title == "foobar"
  end

  test "resources without a json_api are not included in the schema", %{open_api_spec: api_spec} do
    schema_keys = api_spec.components.schemas |> Map.keys()
    assert "tags" not in schema_keys
  end

  test "resource descriptions are used in the generated specification if provided", %{
    open_api_spec: api_spec
  } do
    # The default description
    post = api_spec.components.schemas["post"]
    assert post.description == "A \"Resource object\" representing a post"

    # A custom description read from the resource
    author = api_spec.components.schemas["author"]
    assert author.description == "This is an author!"
  end

  test "API routes are mapped to OpenAPI Operations", %{open_api_spec: %OpenApi{} = api_spec} do
    assert map_size(api_spec.paths) == 11

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

  test "generic routes have properly specified returns", %{open_api_spec: %OpenApi{} = api_spec} do
    assert generic_action_schema = api_spec.paths["/authors/say_hello/{to}"].post

    assert [
             %OpenApiSpex.Parameter{
               name: "to",
               in: :path,
               schema: %OpenApiSpex.Schema{type: :string}
             }
           ] = generic_action_schema.parameters

    assert %OpenApiSpex.Schema{
             type: :object,
             required: [:from],
             properties: %{from: %OpenApiSpex.Schema{type: :string}},
             additionalProperties: false
           } =
             generic_action_schema.requestBody.content["application/vnd.api+json"].schema.properties.data

    assert %OpenApiSpex.Schema{type: :string} =
             generic_action_schema.responses[201].content["application/vnd.api+json"].schema
  end

  test "generic routes have properly specified returns in the case of maps", %{
    open_api_spec: %OpenApi{} = api_spec
  } do
    assert generic_action_schema = api_spec.paths["/authors/returns_map"].get

    assert [] = generic_action_schema.parameters

    refute generic_action_schema.requestBody

    assert %OpenApiSpex.Schema{
             type: :object,
             required: [:b],
             properties: %{
               a: %{"anyOf" => [%OpenApiSpex.Schema{type: :integer}, %{"type" => "null"}]},
               b: %OpenApiSpex.Schema{type: :string}
             }
           } = generic_action_schema.responses[200].content["application/vnd.api+json"].schema
  end

  test "generic routes have properly specified returns in the case of structs", %{
    open_api_spec: %OpenApi{} = api_spec
  } do
    assert generic_action_schema = api_spec.paths["/authors/get_foo"].get

    assert [] = generic_action_schema.parameters

    assert %OpenApiSpex.Schema{
             type: :object,
             required: [:bio],
             properties: %{
               bio: %OpenApiSpex.Schema{
                 type: :object,
                 properties: %{
                   history: %{
                     "anyOf" => [%OpenApiSpex.Schema{type: :string}, %{"type" => "null"}]
                   }
                 }
               }
             },
             additionalProperties: false
           } =
             generic_action_schema.requestBody.content["application/vnd.api+json"].schema.properties.data

    assert %OpenApiSpex.Schema{
             type: :object,
             required: [],
             properties: %{
               foo: %{
                 "anyOf" => [
                   %OpenApiSpex.Schema{
                     type: :string,
                     description: "Field included by default.",
                     nullable: true
                   },
                   %{"type" => "null"}
                 ]
               }
             }
           } = generic_action_schema.responses[200].content["application/vnd.api+json"].schema
  end

  test "generic routes can omit returns, getting a `success/failure` response", %{
    open_api_spec: %OpenApi{} = api_spec
  } do
    assert generic_action_schema = api_spec.paths["/authors/trigger_job"].post

    assert [
             %OpenApiSpex.Parameter{
               name: :job_id,
               in: :query,
               description: "job_id",
               required: false,
               schema: %OpenApiSpex.Schema{type: :string}
             }
           ] = generic_action_schema.parameters

    refute generic_action_schema.requestBody

    assert %OpenApiSpex.Schema{
             type: :object,
             properties: %{success: %OpenApiSpex.Schema{enum: [true]}}
           } =
             generic_action_schema.responses[201].content["application/vnd.api+json"].schema
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
      assert api_spec.components.schemas["author-filter-name"].properties[:contains]
      assert filter.in == :query
      assert filter.required == false
      assert filter.style == :deepObject
      assert %OpenApiSpex.Reference{"$ref": "#/components/schemas/post-filter"} = filter.schema
      assert schema = api_spec.components.schemas["post-filter"]
      assert schema.type == :deepObject

      assert %{
               properties: %{
                 author: %OpenApiSpex.Reference{"$ref": "#/components/schemas/author-filter"},
                 author_id: %OpenApiSpex.Reference{
                   "$ref": "#/components/schemas/post-filter-author_id"
                 },
                 count_of_tags: %OpenApiSpex.Reference{
                   "$ref": "#/components/schemas/post-filter-count_of_tags"
                 },
                 email: %OpenApiSpex.Reference{"$ref": "#/components/schemas/post-filter-email"},
                 hidden: %OpenApiSpex.Reference{"$ref": "#/components/schemas/post-filter-hidden"},
                 id: %OpenApiSpex.Reference{"$ref": "#/components/schemas/post-filter-id"},
                 name: %OpenApiSpex.Reference{"$ref": "#/components/schemas/post-filter-name"},
                 and: %Schema{
                   type: :array,
                   items: %OpenApiSpex.Reference{
                     "$ref": "#/components/schemas/post-filter"
                   },
                   uniqueItems: true
                 },
                 or: %Schema{
                   type: :array,
                   items: %OpenApiSpex.Reference{
                     "$ref": "#/components/schemas/post-filter"
                   },
                   uniqueItems: true
                 },
                 name_twice: %OpenApiSpex.Reference{
                   "$ref": "#/components/schemas/post-filter-name_twice"
                 },
                 not: %OpenApiSpex.Reference{"$ref": "#/components/schemas/post-filter"}
               }
             } = schema

      %OpenApiSpex.Operation{} = operation = api_spec.paths["/authors/no_filter"].get
      refute Enum.any?(operation.parameters, &(&1.name == :filter))

      %OpenApiSpex.Operation{} = operation = api_spec.paths["/authors_no_filter"].get
      refute Enum.any?(operation.parameters, &(&1.name == :filter))
    end

    test "sort parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      %OpenApiSpex.Parameter{} = sort = operation.parameters |> Enum.find(&(&1.name == :sort))
      assert sort.in == :query
      assert sort.required == false
      assert sort.style == :form
      assert !sort.explode
      %Schema{} = schema = sort.schema
      assert schema.type == :string

      assert schema.pattern ==
               "^(id|-id|\\+\\+id|--id|name|-name|\\+\\+name|--name|hidden|-hidden|\\+\\+hidden|--hidden|email|-email|\\+\\+email|--email|author_id|-author_id|\\+\\+author_id|--author_id|name_twice|-name_twice|\\+\\+name_twice|--name_twice|count_of_tags|-count_of_tags|\\+\\+count_of_tags|--count_of_tags)(,(id|-id|\\+\\+id|--id|name|-name|\\+\\+name|--name|hidden|-hidden|\\+\\+hidden|--hidden|email|-email|\\+\\+email|--email|author_id|-author_id|\\+\\+author_id|--author_id|name_twice|-name_twice|\\+\\+name_twice|--name_twice|count_of_tags|-count_of_tags|\\+\\+count_of_tags|--count_of_tags))*$"

      %OpenApiSpex.Operation{} = operation = api_spec.paths["/authors/no_filter"].get
      refute Enum.any?(operation.parameters, &(&1.name == :sort))
    end

    test "page parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/posts"].get
      %OpenApiSpex.Parameter{} = page = operation.parameters |> Enum.find(&(&1.name == :page))
      assert page.in == :query
      assert page.required == false
      assert page.style == :deepObject
      %Schema{} = schema = page.schema

      assert schema.properties == %{
               count: %Schema{type: :boolean, default: false},
               limit: %Schema{minimum: 1, type: :integer},
               offset: %Schema{minimum: 0, type: :integer},
               after: %Schema{type: :string},
               before: %Schema{type: :string}
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
      assert schema.type == :string
      assert schema.pattern == "^(tags)(,(tags))*$"
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

    test "embedded attribute types are expanded", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["/authors"].get
      response = operation.responses[200]
      schema = response.content["application/vnd.api+json"].schema
      assert schema.type == :object
      assert schema.properties.data.type == :array
      assert schema.properties.data.uniqueItems == true
      assert schema.properties.data.items."$ref" == "#/components/schemas/author"

      assert %OpenApiSpex.Schema{
               required: [:type, :id],
               type: :object,
               properties: %{
                 attributes: %OpenApiSpex.Schema{
                   required: [],
                   type: :object,
                   properties: %{
                     name: %{
                       "anyOf" => [
                         %OpenApiSpex.Schema{
                           type: :string,
                           description: "Field included by default.",
                           nullable: true
                         },
                         %{"type" => "null"}
                       ]
                     },
                     bio: %{
                       "anyOf" => [
                         %OpenApiSpex.Schema{
                           required: [],
                           type: :object,
                           properties: %{
                             history: %{
                               "anyOf" => [
                                 %OpenApiSpex.Schema{
                                   type: :string,
                                   description: "Field included by default.",
                                   nullable: true
                                 },
                                 %{"type" => "null"}
                               ]
                             }
                           },
                           description: "Field included by default.",
                           nullable: true
                         },
                         %{"type" => "null"}
                       ]
                     }
                   },
                   additionalProperties: false,
                   description: "An attributes object for a author"
                 },
                 id: %{type: :string},
                 type: %OpenApiSpex.Schema{type: :string},
                 relationships: %OpenApiSpex.Schema{
                   type: :object,
                   properties: %{
                     posts: %OpenApiSpex.Schema{
                       properties: %{
                         data: %OpenApiSpex.Schema{
                           uniqueItems: true,
                           type: :array,
                           items: %{
                             type: :object,
                             description: "Resource identifiers for posts",
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
                           description: "Relationship data for posts"
                         }
                       }
                     }
                   },
                   additionalProperties: false,
                   description: "A relationships object for a author"
                 }
               },
               additionalProperties: false,
               description: "This is an author!"
             } = api_spec.components.schemas["author"]
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
               required: [:type, :id],
               type: :object,
               properties: %{
                 attributes: %OpenApiSpex.Schema{
                   required: [:name, :author_id],
                   type: :object,
                   properties: %{
                     hidden: %{
                       "anyOf" => [
                         %OpenApiSpex.Schema{
                           type: :string,
                           description:
                             "description of attribute :hidden. Field included by default.",
                           nullable: true
                         },
                         %{"type" => "null"}
                       ]
                     },
                     name: %OpenApiSpex.Schema{
                       type: :string,
                       description: "description of attribute :name. Field included by default."
                     },
                     name_twice: %{
                       "anyOf" => [
                         %OpenApiSpex.Schema{type: :string, nullable: true},
                         %{"type" => "null"}
                       ]
                     },
                     author_id: %OpenApiSpex.Schema{
                       type: :string,
                       description: "Field included by default.",
                       format: "uuid"
                     },
                     email: %{
                       "anyOf" => [
                         %OpenApiSpex.Schema{
                           type: :string,
                           description: "Field included by default.",
                           nullable: true
                         },
                         %{"type" => "null"}
                       ]
                     },
                     count_of_tags: %{
                       "anyOf" => [%OpenApiSpex.Schema{type: :integer}, %{"type" => "null"}]
                     }
                   },
                   additionalProperties: false,
                   description: "An attributes object for a post"
                 },
                 id: %{type: :string},
                 type: %OpenApiSpex.Schema{type: :string},
                 relationships: %OpenApiSpex.Schema{
                   type: :object,
                   properties: %{
                     author: %OpenApiSpex.Schema{
                       properties: %{
                         data: %OpenApiSpex.Schema{
                           required: [:type, :id],
                           type: :object,
                           properties: %{
                             id: %OpenApiSpex.Schema{type: :string},
                             meta: %OpenApiSpex.Schema{
                               type: :object,
                               additionalProperties: true
                             },
                             type: %OpenApiSpex.Schema{type: :string}
                           },
                           additionalProperties: false,
                           description: "An identifier for author",
                           nullable: true
                         }
                       }
                     }
                   },
                   additionalProperties: false,
                   description: "A relationships object for a post"
                 }
               },
               additionalProperties: false,
               description: "A \"Resource object\" representing a post"
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
      %Schema{} = schema = include.schema
      assert schema.type == :string
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
      assert schema.type == :string
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
      response = operation.responses[201]
      schema = response.content["application/vnd.api+json"].schema
      assert schema.properties.data."$ref" == "#/components/schemas/post"
    end
  end
end
