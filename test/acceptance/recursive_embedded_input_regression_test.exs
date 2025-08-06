defmodule Test.Acceptance.RecursiveEmbeddedInputRegressionTest do
  use ExUnit.Case, async: true

  alias OpenApiSpex.{OpenApi, Operation}

  # Embedded resource with self-reference for testing recursive input schema generation
  defmodule Comment do
    use Ash.Resource,
      data_layer: :embedded,
      extensions: [AshJsonApi.Resource]

    json_api do
      type("comment")
    end

    attributes do
      attribute(:id, :uuid, public?: true, primary_key?: true, allow_nil?: false, default: &Ash.UUID.generate/0)
      attribute(:content, :string, public?: true, allow_nil?: false)
      attribute(:parent_comment, :struct, constraints: [instance_of: __MODULE__], public?: true)
      attribute(:replies, {:array, :struct}, constraints: [items: [instance_of: __MODULE__]], public?: true, default: [])
    end

    actions do
      default_accept([:content, :parent_comment, :replies])
      defaults([:create, :update])
    end
  end

  # Embedded resource with multiple self-references for deeper testing
  defmodule TreeNode do
    use Ash.Resource,
      data_layer: :embedded,
      extensions: [AshJsonApi.Resource]

    json_api do
      type("tree_node")
    end

    attributes do
      attribute(:id, :uuid, public?: true, primary_key?: true, allow_nil?: false, default: &Ash.UUID.generate/0)
      attribute(:name, :string, public?: true, allow_nil?: false)
      attribute(:left_child, :struct, constraints: [instance_of: __MODULE__], public?: true)
      attribute(:right_child, :struct, constraints: [instance_of: __MODULE__], public?: true)
      attribute(:children, {:array, :struct}, constraints: [items: [instance_of: __MODULE__]], public?: true, default: [])
    end

    actions do
      default_accept([:name, :left_child, :right_child, :children])
      defaults([:create, :update])
    end
  end

  # Main resource for testing create/update operations with recursive embedded inputs
  defmodule BlogPost do
    use Ash.Resource,
      domain: Test.Acceptance.RecursiveEmbeddedInputRegressionTest.Blog,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("blog_post")

      routes do
        base("/blog_posts")
        get(:read)
        index(:read)
        post(:create)
        patch(:update)
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:title, :string, public?: true, allow_nil?: false)
      attribute(:main_comment, Comment, public?: true)
      attribute(:comment_tree, TreeNode, public?: true)
      attribute(:all_comments, {:array, Comment}, public?: true, default: [])
    end

    actions do
      default_accept([:title, :main_comment, :comment_tree, :all_comments])
      defaults([:read, :destroy])

      create :create do
        primary?(true)
        accept([:title, :main_comment, :comment_tree, :all_comments])
      end

      update :update do
        primary?(true)
        accept([:title, :main_comment, :comment_tree, :all_comments])
        require_atomic?(false)
      end
    end
  end

  defmodule Blog do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(BlogPost)
    end
  end

  describe "recursive embedded input types regression test" do
    test "spec generation completes without stack overflow or infinite loops" do
      # This is the core regression test - before the fix, this would cause:
      # 1. Stack overflow from infinite recursion
      # 2. Infinite loop that would hang the test
      # 3. Out of memory errors
      
      start_time = System.monotonic_time(:millisecond)
      
      # Generate spec - this should complete successfully
      assert %OpenApi{} = AshJsonApi.OpenApi.spec(domain: [Blog])
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Should complete in reasonable time (generous limit for CI environments)
      assert duration < 30_000, "Spec generation took #{duration}ms, indicating possible infinite recursion"
    end

    test "recursive embedded inputs use $ref references instead of inline expansion" do
      spec = AshJsonApi.OpenApi.spec(domain: [Blog])

      # Check create operation
      create_operation = spec.paths["/blog_posts"].post
      assert %Operation{} = create_operation

      # Verify request body schema exists
      request_body = create_operation.requestBody
      assert request_body != nil

      schema = request_body.content["application/vnd.api+json"].schema
      attributes = schema.properties.data.properties.attributes

      # Test main_comment attribute - should use $ref to prevent infinite expansion
      main_comment_prop = attributes.properties.main_comment
      assert Map.has_key?(main_comment_prop, "anyOf")

      # Should contain a $ref to an input schema (even if that schema has issues)
      ref_found = 
        main_comment_prop["anyOf"]
        |> Enum.any?(fn item -> 
          is_map(item) && Map.has_key?(item, "$ref") && 
          String.contains?(item["$ref"], "comment-input-create")
        end)

      assert ref_found, "Expected $ref to comment-input-create in main_comment property"

      # Test all_comments array attribute
      all_comments_prop = attributes.properties.all_comments
      assert Map.has_key?(all_comments_prop, "anyOf")

      # Should contain an array that uses $ref for items
      array_with_ref = 
        all_comments_prop["anyOf"]
        |> Enum.find(fn item -> 
          match?(%OpenApiSpex.Schema{type: :array}, item) &&
          is_map(item.items) && 
          Map.has_key?(item.items, "$ref") &&
          String.contains?(item.items["$ref"], "comment-input-create")
        end)

      assert array_with_ref != nil, "Expected array with $ref items in all_comments property"

      # Test comment_tree with TreeNode
      comment_tree_prop = attributes.properties.comment_tree
      assert Map.has_key?(comment_tree_prop, "anyOf")

      tree_ref_found = 
        comment_tree_prop["anyOf"]
        |> Enum.any?(fn item -> 
          is_map(item) && Map.has_key?(item, "$ref") && 
          String.contains?(item["$ref"], "tree_node-input-create")
        end)

      assert tree_ref_found, "Expected $ref to tree_node-input-create in comment_tree property"
    end

    test "update operations also use $ref references for recursive inputs" do
      spec = AshJsonApi.OpenApi.spec(domain: [Blog])

      # Check update operation
      update_operation = spec.paths["/blog_posts/{id}"].patch
      assert %Operation{} = update_operation

      request_body = update_operation.requestBody
      assert request_body != nil

      schema = request_body.content["application/vnd.api+json"].schema
      attributes = schema.properties.data.properties.attributes

      # Test that update operations use different input schema names
      main_comment_prop = attributes.properties.main_comment
      assert Map.has_key?(main_comment_prop, "anyOf")

      update_ref_found = 
        main_comment_prop["anyOf"]
        |> Enum.any?(fn item -> 
          is_map(item) && Map.has_key?(item, "$ref") && 
          String.contains?(item["$ref"], "comment-input-update")
        end)

      assert update_ref_found, "Expected $ref to comment-input-update in update operation"
    end

    test "multiple levels of recursive nesting are handled" do
      spec = AshJsonApi.OpenApi.spec(domain: [Blog])

      create_operation = spec.paths["/blog_posts"].post
      schema = create_operation.requestBody.content["application/vnd.api+json"].schema
      attributes = schema.properties.data.properties.attributes

      # TreeNode has multiple recursive references (left_child, right_child, children)
      comment_tree_prop = attributes.properties.comment_tree

      # Should use $ref instead of deeply nested inline schemas
      tree_ref_found = 
        comment_tree_prop["anyOf"]
        |> Enum.any?(fn item -> 
          is_map(item) && Map.has_key?(item, "$ref") && 
          String.contains?(item["$ref"], "tree_node-input")
        end)

      assert tree_ref_found, "Expected TreeNode recursive references to use $ref"
    end

    test "logs appropriate warnings when recursive embedded inputs are detected" do
      import ExUnit.CaptureLog

      log = capture_log(fn ->
        AshJsonApi.OpenApi.spec(domain: [Blog])
      end)

      # Should log warnings about recursive types being detected
      assert log =~ "Detected recursive embedded input type"
      assert log =~ "Comment"
      assert log =~ "TreeNode"
      assert log =~ "action: create"
      assert log =~ "action: update"
    end

    test "generated spec is still a valid OpenAPI specification" do
      spec = AshJsonApi.OpenApi.spec(domain: [Blog])

      # Basic validation that the spec structure is correct
      assert %OpenApi{} = spec
      assert is_map(spec.paths)
      assert is_map(spec.components.schemas)
      assert spec.info.title != nil
      assert spec.info.version != nil

      # Verify we have the expected operations
      assert Map.has_key?(spec.paths, "/blog_posts")
      assert Map.has_key?(spec.paths, "/blog_posts/{id}")

      # Verify basic resource schemas exist
      assert Map.has_key?(spec.components.schemas, "blog_post")
      assert Map.has_key?(spec.components.schemas, "comment")  # read schema
      assert Map.has_key?(spec.components.schemas, "tree_node")  # read schema
    end

    test "performance regression - multiple spec generations complete quickly" do
      # Test that repeated spec generation doesn't degrade performance
      # (which could indicate memory leaks or accumulating state)
      
      times = for _ <- 1..5 do
        start_time = System.monotonic_time(:millisecond)
        AshJsonApi.OpenApi.spec(domain: [Blog])
        end_time = System.monotonic_time(:millisecond)
        end_time - start_time
      end

      # Each generation should complete reasonably quickly
      Enum.each(times, fn time ->
        assert time < 10_000, "Spec generation took #{time}ms, which may indicate performance regression"
      end)

      # Later generations shouldn't be significantly slower than earlier ones
      avg_first_half = Enum.take(times, 2) |> Enum.sum() |> div(2)
      avg_last_half = Enum.drop(times, 3) |> Enum.sum() |> div(2)
      
      # Allow some variance but not dramatic slowdown
      assert avg_last_half <= avg_first_half * 3, 
        "Performance degraded significantly: first half #{avg_first_half}ms, last half #{avg_last_half}ms"
    end
  end
end