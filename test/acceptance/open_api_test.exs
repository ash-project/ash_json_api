defmodule Test.Acceptance.OpenApiTest do
  use ExUnit.Case, async: true
  alias OpenApiSpex.{OpenApi, Schema}

  defmodule Author do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      routes do
        base("/authors")
        get(:read)
        index(:read)
        patch(:update)
      end
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string)
    end

    relationships do
      has_many(:posts, Test.Acceptance.OpenApiTest.Post, destination_attribute: :author_id)
    end
  end

  defmodule Post do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("post")

      routes do
        base("/posts")
        get(:read)
        index(:read)
        post(:create, relationship_arguments: [{:id, :author}])
      end
    end

    actions do
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
      attribute(:name, :string, allow_nil?: false)
      attribute(:hidden, :string)

      attribute(:email, :string,
        allow_nil?: true,
        constraints: [
          match: ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
        ]
      )
    end

    relationships do
      belongs_to(:author, Test.Acceptance.OpenApiTest.Author, allow_nil?: false)
    end
  end

  defmodule Registry do
    use Ash.Registry

    entries do
      entry(Post)
      entry(Author)
    end
  end

  defmodule Blogs do
    use Ash.Api,
      extensions: [
        AshJsonApi.Api
      ]

    json_api do
      router(Test.Acceptance.OpenApiTest.Router)
      log_errors?(false)
    end

    resources do
      registry(Registry)
    end
  end

  setup do
    api_spec =
      %OpenApi{
        info: %OpenApiSpex.Info{
          title: "My App",
          version: "1.0"
        },
        paths: AshJsonApi.OpenApi.paths(Blogs),
        components: %OpenApiSpex.Components{
          schemas: AshJsonApi.OpenApi.schemas(Blogs),
          responses: AshJsonApi.OpenApi.responses()
        },
        tags: AshJsonApi.OpenApi.tags(Blogs)
      }

    %{open_api_spec: api_spec}
  end

  test "API routes are mapped to OpenAPI Operations", %{open_api_spec: %OpenApi{} = api_spec} do
    assert map_size(api_spec.paths) == 4
    assert %{"authors" => _, "authors/{id}" => _, "posts" => _, "posts/{id}" => _} = api_spec.paths

    assert %OpenApiSpex.Operation{} = api_spec.paths["authors"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["authors/{id}"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["authors/{id}"].patch
    assert nil == api_spec.paths["authors"].post

    assert %OpenApiSpex.Operation{} = api_spec.paths["posts"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["posts/{id}"].get
    assert %OpenApiSpex.Operation{} = api_spec.paths["posts"].post
    assert nil == api_spec.paths["posts/{id}"].patch
  end

  describe "Index route" do
    test "filter parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["posts"].get
      %OpenApiSpex.Parameter{} = filter = operation.parameters |> Enum.find(& &1.name == :filter)
      assert filter.in == :query
      assert filter.required == false
      assert filter.style == :deepObject
      %Schema{} = schema = filter.schema
      assert schema.type == :object
      assert schema.properties == %{
        id: %Schema{format: :uuid, type: :string},
        author: %Schema{type: :string},
        email: %Schema{type: :string},
        hidden: %Schema{type: :string},
        name: %Schema{type: :string}
      }
      assert schema.required == nil
    end

    test "sort parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["posts"].get
      %OpenApiSpex.Parameter{} = sort = operation.parameters |> Enum.find(& &1.name == :sort)
      assert sort.in == :query
      assert sort.required == false
      assert sort.style == :form
      assert !sort.explode
      %Schema{} = schema = sort.schema
      assert schema.type == :array
      assert schema.items.type == :string
      assert schema.items.enum == ["id", "-id", "name", "-name", "hidden", "-hidden", "email", "-email"]
    end

    test "page parameter", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["posts"].get
      %OpenApiSpex.Parameter{} = page = operation.parameters |> Enum.find(& &1.name == :page)
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
      %OpenApiSpex.Operation{} = operation = api_spec.paths["posts"].get
      %OpenApiSpex.Parameter{} = include = operation.parameters |> Enum.find(& &1.name == :include)
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
      %OpenApiSpex.Operation{} = operation = api_spec.paths["posts"].get
      %OpenApiSpex.Parameter{} = fields = operation.parameters |> Enum.find(& &1.name == :fields)
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
      %OpenApiSpex.Operation{} = operation = api_spec.paths["posts"].get
      refute operation.requestBody
    end

    @tag :focus
    test "Response body schema", %{open_api_spec: %OpenApi{} = api_spec} do
      %OpenApiSpex.Operation{} = operation = api_spec.paths["posts"].get
      response = operation.responses[200]
      schema = response.content["application/vnd.api+json"].schema
      assert schema.type == :object
      assert schema.properties.data.type == :array
      assert schema.properties.data.uniqueItems == true
      assert schema.properties.data.items.'$ref' == "#/components/schemas/post"
    end
  end

  describe "Get route" do
    test "id parameter" do
      flunk "TODO"
    end

    test "include parameter" do
      flunk "TODO"
    end

    test "fields parameter" do
      flunk "TODO"
    end

    test "Has no request body" do
      flunk "TODO"
    end

    test "Response body schema" do
      flunk "TODO"
    end
  end

  describe "Create route" do
    test "include parameter" do
      flunk "TODO"
    end

    test "fields parameter" do
      flunk "TODO"
    end

    test "Request body schema" do
      flunk "TODO"
    end

    test "Response body schema" do
      flunk "TODO"
    end
  end
end
