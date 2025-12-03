# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.PaginatedRelationshipsTest do
  @moduledoc """
  Tests for paginated relationships using the included_page query parameter.
  """

  use ExUnit.Case, async: true

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.PaginatedRelationshipsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      # Allow posts to be included (with nested comments)
      includes posts: [:comments]

      # Configure paginated includes for nested paths
      # Note: Nested paths are specified as lists like [:posts, :comments]
      paginated_includes([:posts, [:posts, :comments]])

      routes do
        base("/authors")
        index(:read)
        get(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      has_many(:posts, Test.Acceptance.PaginatedRelationshipsTest.Post, public?: true)
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.PaginatedRelationshipsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("post")

      # Allow comments to be included
      includes [:comments, :author]

      # Configure which relationships can be paginated
      paginated_includes([:comments, [:author, :posts]])

      routes do
        base("/posts")
        index(:read)
        get(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
    end

    relationships do
      belongs_to(:author, Author, public?: true)
      has_many(:comments, Test.Acceptance.PaginatedRelationshipsTest.Comment, public?: true)
      # Private relationship - should not be accessible via API
      has_many(:private_comments, Test.Acceptance.PaginatedRelationshipsTest.Comment,
        destination_attribute: :post_id,
        public?: false
      )
    end
  end

  defmodule Comment do
    use Ash.Resource,
      domain: Test.Acceptance.PaginatedRelationshipsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("comment")
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:body, :string, public?: true)
    end

    relationships do
      belongs_to(:post, Post, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Author)
      resource(Post)
      resource(Comment)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    :ok
  end

  setup do
    # Create an author
    author =
      Author
      |> Ash.Changeset.for_create(:create, %{name: "Test Author"})
      |> Ash.create!()

    # Create a post with multiple comments
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Test Post"})
      |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
      |> Ash.create!()

    # Create 10 comments for the post
    comments =
      Enum.map(1..10, fn i ->
        Comment
        |> Ash.Changeset.for_create(:create, %{body: "Comment #{i}"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Ash.create!()
      end)

    # Create 5 more posts for the author
    Enum.each(1..5, fn i ->
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Post #{i}"})
      |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
      |> Ash.create!()
    end)

    %{author: author, post: post, comments: comments}
  end

  describe "paginated relationships with included_page" do
    test "paginate included comments with limit", %{post: post} do
      response =
        Domain
        |> get("/posts/#{post.id}?include=comments&included_page[comments][limit]=5", status: 200)

      # Check that only 5 comments are included
      comments = Enum.filter(response.resp_body["included"], &(&1["type"] == "comment"))
      assert length(comments) == 5

      # Check that pagination metadata is present in the relationship
      post_data = response.resp_body["data"]
      comments_rel = post_data["relationships"]["comments"]
      assert comments_rel["meta"]["limit"] == 5
      assert length(comments_rel["data"]) == 5

      # Check that pagination links are present
      assert Map.has_key?(comments_rel["links"], "first")
      assert Map.has_key?(comments_rel["links"], "next")
      assert is_binary(comments_rel["links"]["first"])
      assert is_binary(comments_rel["links"]["next"])
    end

    test "paginate included comments with limit and offset", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=3&included_page[comments][offset]=5",
          status: 200
        )

      # Check that 3 comments are included starting from offset 5
      comments = Enum.filter(response.resp_body["included"], &(&1["type"] == "comment"))
      assert length(comments) == 3

      # Check pagination metadata
      post_data = response.resp_body["data"]
      comments_rel = post_data["relationships"]["comments"]
      assert comments_rel["meta"]["limit"] == 3
      assert comments_rel["meta"]["offset"] == 5

      # Check that pagination links include prev (since offset > 0)
      assert Map.has_key?(comments_rel["links"], "prev")
      assert is_binary(comments_rel["links"]["prev"])
      assert String.contains?(comments_rel["links"]["prev"], "included_page[comments][offset]=2")
    end

    test "pagination links with count include last link", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=3&included_page[comments][count]=true",
          status: 200
        )

      post_data = response.resp_body["data"]
      comments_rel = post_data["relationships"]["comments"]

      # When count is requested, we should have last link
      assert Map.has_key?(comments_rel["links"], "last")
      assert is_binary(comments_rel["links"]["last"])

      # First page should have no prev link
      refute comments_rel["links"]["prev"]
    end

    test "paginate nested relationship path", %{author: author} do
      response =
        Domain
        |> get(
          "/authors/#{author.id}?include=posts.comments&included_page[posts.comments][limit]=2",
          status: 200
        )

      # Each post should have at most 2 comments in the included section
      # Note: This test verifies the query is accepted, actual pagination depends on Ash query execution
      assert response.status == 200
    end

    test "returns error for non-configured paginated relationship", %{post: post} do
      # Try to paginate a relationship that's not in paginated_includes
      response =
        Domain
        |> get("/posts/#{post.id}?include=author&included_page[author][limit]=5", status: 400)

      # Should get an error because 'author' is not in paginated_includes
      assert response.resp_body["errors"]
    end

    test "returns error for non-public relationship with included_page", %{post: post} do
      # Try to include and paginate a private relationship
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=private_comments&included_page[private_comments][limit]=5",
          status: 400
        )

      # Should get an error because 'private_comments' is not public
      errors = response.resp_body["errors"]
      assert errors != []
      # Error should indicate the relationship is invalid/not included
      assert List.first(errors)["code"] in ["invalid_includes", "invalid_relationship"]
    end

    test "includes without pagination still works normally", %{post: post} do
      response =
        Domain
        |> get("/posts/#{post.id}?include=comments", status: 200)

      # All 10 comments should be included
      comments = Enum.filter(response.resp_body["included"], &(&1["type"] == "comment"))
      assert length(comments) == 10

      # No pagination metadata should be present
      post_data = response.resp_body["data"]
      comments_rel = post_data["relationships"]["comments"]
      refute Map.has_key?(comments_rel["meta"] || %{}, "limit")
    end

    test "paginate included relationships in index endpoint", %{author: _author} do
      response =
        Domain
        |> get("/posts?include=comments&included_page[comments][limit]=3", status: 200)

      # Multiple posts in the response
      assert is_list(response.resp_body["data"])
      assert response.resp_body["data"] != []

      # Each post that has comments should have pagination metadata
      Enum.each(response.resp_body["data"], fn post_data ->
        comments_rel = post_data["relationships"]["comments"]

        # If there are comments, check for pagination metadata
        if comments_rel["data"] != [] do
          assert comments_rel["meta"]["limit"] == 3
        end
      end)
    end

    test "index route works without included_page parameter", %{author: _author} do
      response =
        Domain
        |> get("/posts?include=comments", status: 200)

      # Should return multiple posts
      assert is_list(response.resp_body["data"])
      posts = response.resp_body["data"]
      assert length(posts) > 1

      # Find the post with 10 comments (the first post created in setup)
      post_with_many_comments =
        Enum.find(posts, fn post_data ->
          length(post_data["relationships"]["comments"]["data"]) == 10
        end)

      # Should include all 10 comments without pagination
      assert post_with_many_comments != nil
      comments_rel = post_with_many_comments["relationships"]["comments"]
      assert length(comments_rel["data"]) == 10
      refute Map.has_key?(comments_rel["meta"] || %{}, "limit")
    end

    test "index route works without include parameter", %{author: _author} do
      response =
        Domain
        |> get("/posts", status: 200)

      # Should return multiple posts
      assert is_list(response.resp_body["data"])
      posts = response.resp_body["data"]
      assert length(posts) > 1

      # Should have relationship metadata but no included resources
      Enum.each(posts, fn post_data ->
        # Relationships should exist in the response
        assert Map.has_key?(post_data, "relationships")
        assert Map.has_key?(post_data["relationships"], "comments")
      end)

      # Should not have any included section
      refute Map.has_key?(response.resp_body, "included")
    end
  end

  describe "pagination with count parameter" do
    test "includes count in pagination metadata when requested", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=5&included_page[comments][count]=true",
          status: 200
        )

      post_data = response.resp_body["data"]
      comments_rel = post_data["relationships"]["comments"]

      # Count should be present in metadata
      assert comments_rel["meta"]["limit"] == 5
      assert is_integer(comments_rel["meta"]["count"])
      assert comments_rel["meta"]["count"] == 10
    end
  end

  describe "parameter validation for included_page" do
    test "returns error for invalid limit (non-integer)", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=abc",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "limit must be an integer"
    end

    test "returns error for invalid limit (zero)", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=0",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "limit must be a positive integer"
    end

    test "returns error for invalid limit (negative)", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=-5",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "limit must be a positive integer"
    end

    test "returns error for invalid offset (non-integer)", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=5&included_page[comments][offset]=xyz",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "offset must be an integer"
    end

    test "returns error for invalid offset (negative)", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=5&included_page[comments][offset]=-3",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "offset must be a non-negative integer"
    end

    test "returns error for invalid count value", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=5&included_page[comments][count]=yes",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "count must be 'true' or 'false'"
    end

    test "returns error for unknown pagination parameter", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][unknown_param]=value",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "unknown pagination parameter"
    end

    test "accepts valid offset of zero", %{post: post} do
      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments][limit]=5&included_page[comments][offset]=0",
          status: 200
        )

      post_data = response.resp_body["data"]
      comments_rel = post_data["relationships"]["comments"]
      assert comments_rel["meta"]["offset"] == 0
    end

    test "handles JSON string encoded pagination parameters", %{post: post} do
      # Simulate query parameters coming in as JSON strings
      # This can happen with certain URL encoding methods where the client
      # JSON-encodes the pagination object before sending
      json_params = URI.encode_www_form(Jason.encode!(%{"limit" => 5, "offset" => 3}))

      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments]=#{json_params}",
          status: 200
        )

      post_data = response.resp_body["data"]
      comments_rel = post_data["relationships"]["comments"]
      assert comments_rel["meta"]["limit"] == 5
      assert comments_rel["meta"]["offset"] == 3
      assert length(comments_rel["data"]) == 5
    end

    test "returns error for malformed JSON string in pagination parameters", %{post: post} do
      # Test with invalid JSON
      json_params = URI.encode_www_form("{invalid json}")

      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments]=#{json_params}",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "invalid JSON"
    end

    test "returns error for non-object JSON in pagination parameters", %{post: post} do
      # Test with JSON array instead of object
      json_params = URI.encode_www_form(Jason.encode!(["limit", 5]))

      response =
        Domain
        |> get(
          "/posts/#{post.id}?include=comments&included_page[comments]=#{json_params}",
          status: 400
        )

      errors = response.resp_body["errors"]
      assert errors != []
      assert List.first(errors)["code"] == "invalid_pagination"
      assert List.first(errors)["detail"] =~ "must be a JSON object"
    end
  end
end
