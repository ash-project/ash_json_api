defmodule Test.Acceptance.JsonSchemaTest do
  use ExUnit.Case, async: true

  defmodule Node do
    use Ash.Resource,
      data_layer: :embedded,
      extensions: [
        AshJsonApi.Resource
      ]

    json_api do
      type("node")
    end

    attributes do
      attribute(:name, :string, public?: true)
      attribute(:child, :struct, constraints: [instance_of: __MODULE__], public?: true)
    end
  end

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.JsonSchemaTest.Blogs,
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
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, public?: true)
    end

    relationships do
      has_many(:posts, Test.Acceptance.JsonSchemaTest.Post,
        destination_attribute: :author_id,
        public?: true
      )
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.JsonSchemaTest.Blogs,
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
      attribute(:name, :string, allow_nil?: false, public?: true)
      attribute(:hidden, :string, public?: true)

      attribute(:email, :string,
        public?: true,
        allow_nil?: true,
        constraints: [
          match: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
        ]
      )
    end

    relationships do
      belongs_to(:author, Test.Acceptance.JsonSchemaTest.Author, allow_nil?: false, public?: true)
    end
  end

  defmodule Tree do
    use Ash.Resource,
      domain: Test.Acceptance.JsonSchemaTest.Blogs,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("tree")

      routes do
        base("/trees")
        get(:read)
        index(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:root, Node, public?: true)
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
      resource(Tree)
    end
  end

  setup do
    Application.put_env(:ash_json_api, Blogs, json_api: [test_router: Router])

    json_api = AshJsonApi.JsonSchema.generate([Blogs])

    %{json_api: json_api}
  end

  describe "generate json api schema" do
    test "prepends slashes to hrefs", %{json_api: json_api} do
      assert Enum.all?(
               json_api["links"],
               fn %{"href" => href} ->
                 # Just one slash
                 String.starts_with?(href, "/") &&
                   !String.starts_with?(href, "//")
               end
             )
    end

    test "handles self-referential embedded resources without infinite loop" do
      # This should complete without timing out
      # If it loops infinitely, the test will timeout
      json_api = AshJsonApi.JsonSchema.generate([Blogs])

      # Basic assertion to ensure schema was generated
      assert is_map(json_api)
      assert Map.has_key?(json_api, "links")
    end

    test "handles self-referential embedded resources in OpenAPI schema without infinite loop" do
      # This should complete without timing out
      # If it loops infinitely, the test will timeout
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          open_api_spec = AshJsonApi.OpenApi.spec(domain: [Blogs])

          # Basic assertion to ensure schema was generated
          assert %OpenApiSpex.OpenApi{} = open_api_spec
          schemas = open_api_spec.components.schemas
          assert is_map(schemas)

          # Verify that the embedded resource with JSON API type gets its own schema
          assert Map.has_key?(schemas, "node")
          node_schema = schemas["node"]
          assert node_schema.type == :object

          # Verify that tree resource uses $ref to reference the node schema
          tree_schema = schemas["tree"]
          assert tree_schema.type == :object
          tree_attributes = tree_schema.properties.attributes
          root_property = tree_attributes.properties.root

          # Should be an anyOf with the reference and null (because the attribute allows nil)
          assert Map.has_key?(root_property, "anyOf")
          any_of = root_property["anyOf"]
          assert length(any_of) == 2

          # First item should be the node schema (inline)
          node_schema =
            Enum.find(any_of, fn item ->
              match?(%OpenApiSpex.Schema{}, item) && item.type == :object
            end)

          assert node_schema != nil
          assert node_schema.type == :object

          # The child property within the node schema should reference the node schema
          child_property = node_schema.properties.child
          assert Map.has_key?(child_property, "anyOf")
          child_any_of = child_property["anyOf"]

          # Find the $ref in the child's anyOf
          ref_schema = Enum.find(child_any_of, &Map.has_key?(&1, "$ref"))
          assert ref_schema["$ref"] == "#/components/schemas/node"

          # Second item should be null type
          null_schema =
            Enum.find(any_of, fn item ->
              is_map(item) && not match?(%OpenApiSpex.Schema{}, item) && item["type"] == "null"
            end)

          assert null_schema["type"] == "null"
        end)

      # Verify that the warning was logged for recursive type
      assert log =~
               "Detected recursive embedded type with JSON API type: Test.Acceptance.JsonSchemaTest.Node"
    end
  end
end
