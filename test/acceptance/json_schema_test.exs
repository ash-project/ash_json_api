# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

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
      open_api_spec = AshJsonApi.OpenApi.spec(domain: [Blogs])

      # Basic assertion to ensure schema was generated
      assert %OpenApiSpex.OpenApi{} = open_api_spec
      schemas = open_api_spec.components.schemas
      assert is_map(schemas)

      # Verify that the embedded resource with JSON API type gets its own schema
      assert Map.has_key?(schemas, "node-type")
      node_schema = schemas["node-type"]
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
      assert ref_schema["$ref"] == "#/components/schemas/node-type"

      # Second item should be null type
      null_schema =
        Enum.find(any_of, fn item ->
          is_map(item) && not match?(%OpenApiSpex.Schema{}, item) && item["type"] == "null"
        end)

      assert null_schema["type"] == "null"
    end

    test "handles recursive embedded inputs for create/update operations without infinite loop" do
      # This test ensures that embedded resources with self-references in input schemas
      # (for create/update operations) properly use $ref references and don't cause stack overflow
      import ExUnit.CaptureLog

      # Create a standalone test module for this specific test
      defmodule RecursiveInputTest do
        defmodule RecursiveComment do
          use Ash.Resource,
            data_layer: :embedded,
            extensions: [AshJsonApi.Resource]

          json_api do
            type("recursive-comment")
          end

          attributes do
            attribute(:content, :string, public?: true)
            attribute(:parent, :struct, constraints: [instance_of: __MODULE__], public?: true)

            attribute(:replies, {:array, :struct},
              constraints: [items: [instance_of: __MODULE__]],
              public?: true
            )
          end
        end

        defmodule ArticleWithComments do
          use Ash.Resource,
            domain: Test.Acceptance.JsonSchemaTest.RecursiveInputTest.BlogDomain,
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshJsonApi.Resource]

          ets do
            private?(true)
          end

          json_api do
            type("article-with-comments")

            routes do
              base("/articles")
              get(:read)
              post(:create)
              patch(:update)
            end
          end

          actions do
            default_accept(:*)
            defaults([:read, :create, :update])
          end

          attributes do
            uuid_primary_key(:id, writable?: true)
            attribute(:title, :string, public?: true)
            attribute(:main_comment, RecursiveComment, public?: true)
          end
        end

        defmodule BlogDomain do
          use Ash.Domain,
            otp_app: :ash_json_api,
            extensions: [AshJsonApi.Domain]

          json_api do
            log_errors?(false)
          end

          resources do
            resource(ArticleWithComments)
          end
        end
      end

      log =
        capture_log(fn ->
          # Generate spec outside capture_log first to check it
          spec = AshJsonApi.OpenApi.spec(domain: [RecursiveInputTest.BlogDomain])

          # Verify spec generation completes without stack overflow
          assert %OpenApiSpex.OpenApi{} = spec

          # Check that the create operation request body is properly generated
          create_path = spec.paths["/articles"]
          assert create_path != nil

          create_op = create_path.post
          assert create_op != nil

          # Verify the request body schema exists
          assert create_op.requestBody != nil

          # The key test is that we got here without stack overflow
          # Additional checks to verify the schemas are properly structured
          schemas = spec.components.schemas

          # Verify the main resource schema exists
          assert Map.has_key?(schemas, "article-with-comments")

          # Verify the embedded recursive-comment schema exists
          assert Map.has_key?(schemas, "recursive-comment-type")

          # Check patch operation as well
          patch_path = spec.paths["/articles/{id}"]
          assert patch_path != nil

          patch_op = patch_path.patch
          assert patch_op != nil
          assert patch_op.requestBody != nil

          # Verify that any referenced schemas exist in components
          # This ensures client generation tools won't fail with missing $ref errors
          schema_keys = Map.keys(schemas)

          # If there are any input schemas, they should be properly defined
          input_schemas = Enum.filter(schema_keys, &String.contains?(&1, "-input-"))

          Enum.each(input_schemas, fn schema_name ->
            schema = Map.get(schemas, schema_name)
            assert schema != nil, "Schema #{schema_name} should be defined"
            assert schema.type == :object, "Schema #{schema_name} should be an object type"
          end)
        end)

      # Additionally verify that warnings were logged for recursive input types
      # This proves the recursion detection is working
      if log != "" do
        assert log =~ "recursive" or log =~ "Recursive",
               "Expected some indication of recursive type handling in logs"
      end
    end
  end
end
