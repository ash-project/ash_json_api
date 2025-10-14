# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiTest.FetchingData.InclusionOfRelatedResources do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0

  defmodule Author do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      routes do
        base("/authors")
        get(:read)
        index(:read)
      end

      includes posts: [:author]
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    relationships do
      has_many(:posts, AshJsonApiTest.FetchingData.InclusionOfRelatedResources.Post,
        public?: true,
        destination_attribute: :author_id
      )
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    ets do
      private?(true)
    end

    json_api do
      type("post")

      routes do
        base("/posts")
        get(:read)
        index(:read)
      end

      includes author: [:posts], comments: []
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      belongs_to(:author, Author, public?: true)

      has_many(:comments, AshJsonApiTest.FetchingData.InclusionOfRelatedResources.Comment,
        public?: true
      )
    end
  end

  defmodule Comment do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    ets do
      private?(true)
    end

    json_api do
      type("comment")
      default_fields [:text, :calc]
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:text, :string, public?: true)
    end

    calculations do
      calculate(:calc, :string, expr("hello"))
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

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  # JSON:API 1.0 Specification
  # --------------------------
  # An endpoint MAY return resources related to the primary data by default.
  # --------------------------
  describe "default related resources" do
    @describetag :spec_may
    # Do we want to implement this?
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # An endpoint MAY also support an include request parameter to allow the client to customize which related resources should be returned.
  # --------------------------
  describe "include request parameter" do
    @describetag :spec_may
    test "resource endpoint with include param of an empty to-one relationship (linkage)" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      assert %{
               resp_body: %{
                 "data" => %{
                   "relationships" => %{
                     "author" => %{"data" => nil}
                   }
                 }
               }
             } = get(Domain, "/posts/#{post.id}/?include=author", status: 200)
    end

    test "resource endpoint with include param of to-one relationship (linkage)" do
      # GET /posts/1?include=author
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      author_id = author.id

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.create!()

      assert %{
               resp_body: %{
                 "data" => %{
                   "relationships" => %{
                     "author" => %{"data" => %{"id" => ^author_id, "type" => "author"}}
                   }
                 }
               }
             } = get(Domain, "/posts/#{post.id}/?include=author", status: 200)
    end

    test "resource endpoint with include param of to-one relationship (inclusion)" do
      # GET /posts/1?include=author
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      author_id = author.id

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.create!()

      Domain
      |> get("/posts/#{post.id}/?include=author", status: 200)
      |> assert_has_matching_include(fn
        %{"type" => "author", "id" => ^author_id} ->
          true

        _ ->
          false
      end)
    end

    test "resource endpoint with include param of empty to-many relationship" do
      # GET /posts/1?include=comments
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      assert %{
               resp_body: %{
                 "data" => %{
                   "relationships" => %{
                     "comments" => %{"data" => []}
                   }
                 }
               }
             } = get(Domain, "/posts/#{post.id}/?include=comments", status: 200)
    end

    test "resource endpoint with include param of to-many relationship" do
      # GET /posts/1?include=comments
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.create!()

      %{id: comment1_id} =
        Comment
        |> Ash.Changeset.for_create(:create, %{post_id: post.id, text: "foo"})
        |> Ash.create!()

      %{id: comment2_id} =
        Comment
        |> Ash.Changeset.for_create(:create, %{post_id: post.id, text: "bar"})
        |> Ash.create!()

      Domain
      |> get("/posts/#{post.id}/?include=comments", status: 200)
      |> assert_has_matching_include(fn
        %{"type" => "comment", "id" => ^comment1_id} ->
          true

        _ ->
          false
      end)
      |> assert_has_matching_include(fn
        %{"type" => "comment", "id" => ^comment2_id} ->
          true

        _ ->
          false
      end)
    end

    test "includes have fields for calcs in their default_fields" do
      # GET /posts/1?include=comments
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.create!()

      %{id: comment1_id} =
        Comment
        |> Ash.Changeset.for_create(:create, %{post_id: post.id, text: "foo"})
        |> Ash.create!()

      Domain
      |> get("/posts/#{post.id}/?include=comments&filter_included[comments][text]=foo",
        status: 200
      )
      |> assert_has_matching_include(fn
        %{"type" => "comment", "id" => ^comment1_id, "attributes" => %{"calc" => "hello"}} ->
          true

        _ ->
          false
      end)
    end

    test "includes can be filtered" do
      # GET /posts/1?include=comments
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.create!()

      %{id: comment1_id} =
        Comment
        |> Ash.Changeset.for_create(:create, %{post_id: post.id, text: "foo"})
        |> Ash.create!()

      %{id: comment2_id} =
        Comment
        |> Ash.Changeset.for_create(:create, %{post_id: post.id, text: "bar"})
        |> Ash.create!()

      Domain
      |> get("/posts/#{post.id}/?include=comments&filter_included[comments][text]=foo",
        status: 200
      )
      |> assert_has_matching_include(fn
        %{"type" => "comment", "id" => ^comment1_id} ->
          true

        _ ->
          false
      end)
      |> refute_has_matching_include(fn
        %{"type" => "comment", "id" => ^comment2_id} ->
          true

        _ ->
          false
      end)
    end

    test "includes can be sorted" do
      # GET /posts/1?include=comments
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.create!()

      %{id: comment1_id} =
        Comment
        |> Ash.Changeset.for_create(:create, %{post_id: post.id, text: "foo"})
        |> Ash.create!()

      %{id: comment2_id} =
        Comment
        |> Ash.Changeset.for_create(:create, %{post_id: post.id, text: "bar"})
        |> Ash.create!()

      sorted_ids =
        Domain
        |> get("/posts/#{post.id}/?include=comments&sort_included[comments]=text",
          status: 200
        )
        |> Map.get(:resp_body)
        |> get_in(["data", "relationships", "comments", "data", Access.all(), "id"])

      assert sorted_ids == [comment2_id, comment1_id]

      sorted_desc_ids =
        Domain
        |> get("/posts/#{post.id}/?include=comments&sort_included[comments]=-text",
          status: 200
        )
        |> Map.get(:resp_body)
        |> get_in(["data", "relationships", "comments", "data", Access.all(), "id"])

      assert sorted_desc_ids == [comment1_id, comment2_id]
    end
  end
end
