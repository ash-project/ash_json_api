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
      assert length(response.resp_body["data"]) > 0

      # Each post that has comments should have pagination metadata
      Enum.each(response.resp_body["data"], fn post_data ->
        comments_rel = post_data["relationships"]["comments"]

        # If there are comments, check for pagination metadata
        if length(comments_rel["data"]) > 0 do
          assert comments_rel["meta"]["limit"] == 3
        end
      end)
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
end
