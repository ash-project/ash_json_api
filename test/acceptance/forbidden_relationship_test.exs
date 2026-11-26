# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.ForbiddenRelationshipTest do
  use ExUnit.Case, async: true

  # Authors and notes refuse reads (rather than filtering them) for non-admin
  # actors, so relationships to them with `allow_forbidden_field? true` load as
  # `%Ash.ForbiddenField{}` instead of failing the whole read.
  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.ForbiddenRelationshipTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource],
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private?(true)
    end

    json_api do
      type("author")
    end

    policies do
      policy action_type(:read) do
        access_type(:strict)
        authorize_if(actor_attribute_equals(:admin, true))
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      has_many(:posts, Test.Acceptance.ForbiddenRelationshipTest.Post, public?: true)
    end
  end

  defmodule Note do
    use Ash.Resource,
      domain: Test.Acceptance.ForbiddenRelationshipTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource],
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private?(true)
    end

    json_api do
      type("note")
    end

    policies do
      policy action_type(:read) do
        access_type(:strict)
        authorize_if(actor_attribute_equals(:admin, true))
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:body, :string, public?: true)
    end

    relationships do
      belongs_to(:post, Test.Acceptance.ForbiddenRelationshipTest.Post, public?: true)
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.ForbiddenRelationshipTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("post")
      includes([:notes, :comments, author: [:posts]])

      routes do
        base("/posts")
        get(:read)
        index(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
    end

    relationships do
      belongs_to(:author, Author, public?: true, allow_forbidden_field?: true)
      has_many(:notes, Note, public?: true, allow_forbidden_field?: true)
      has_many(:comments, Test.Acceptance.ForbiddenRelationshipTest.Comment, public?: true)
    end
  end

  defmodule Comment do
    use Ash.Resource,
      domain: Test.Acceptance.ForbiddenRelationshipTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("comment")
    end

    actions do
      default_accept(:*)
      defaults([:create, :read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:body, :string, public?: true)
    end

    relationships do
      belongs_to(:post, Post, public?: true)
      belongs_to(:author, Author, public?: true, allow_forbidden_field?: true)
    end
  end

  defmodule Review do
    use Ash.Resource,
      domain: Test.Acceptance.ForbiddenRelationshipTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("review")
      always_include_linkage([:author])

      routes do
        base("/reviews")
        get(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:body, :string, public?: true)
    end

    relationships do
      belongs_to(:author, Author, public?: true, allow_forbidden_field?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Author)
      resource(Note)
      resource(Post)
      resource(Comment)
      resource(Review)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  @admin %{admin: true}
  @non_admin %{admin: false}

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    author = Ash.create!(Author, %{name: "Ann"}, authorize?: false)
    post = Ash.create!(Post, %{title: "Hello", author_id: author.id})
    note = Ash.create!(Note, %{body: "Secret", post_id: post.id}, authorize?: false)
    comment = Ash.create!(Comment, %{body: "Nice", post_id: post.id, author_id: author.id})
    review = Ash.create!(Review, %{body: "Great", author_id: author.id})

    %{author: author, post: post, note: note, comment: comment, review: review}
  end

  describe "forbidden relationships in includes" do
    test "a forbidden to-one relationship is left out", %{post: post} do
      response = get(Domain, "/posts/#{post.id}?include=author", status: 200, actor: @non_admin)

      assert %{"included" => [], "data" => %{"relationships" => %{"author" => author}}} =
               response.resp_body

      refute Map.has_key?(author, "data")
    end

    test "a forbidden to-many relationship is left out", %{post: post} do
      response = get(Domain, "/posts?include=notes", status: 200, actor: @non_admin)

      assert %{"included" => [], "data" => [%{"id" => id, "relationships" => relationships}]} =
               response.resp_body

      assert id == post.id
      refute Map.has_key?(relationships["notes"], "data")
    end

    test "a forbidden relationship does not hide permitted ones", %{post: post, comment: comment} do
      response =
        get(Domain, "/posts/#{post.id}?include=author,comments", status: 200, actor: @non_admin)

      %{"included" => included, "data" => %{"relationships" => relationships}} =
        response.resp_body

      assert [%{"type" => "comment", "id" => comment_id}] = included
      assert comment_id == comment.id
      assert relationships["comments"]["data"] == [%{"type" => "comment", "id" => comment.id}]
      refute Map.has_key?(relationships["author"], "data")
    end

    test "includes nested beneath a forbidden relationship are left out", %{post: post} do
      response =
        get(Domain, "/posts/#{post.id}?include=author.posts", status: 200, actor: @non_admin)

      assert %{"included" => [], "data" => %{"relationships" => %{"author" => author}}} =
               response.resp_body

      refute Map.has_key?(author, "data")
    end

    test "a forbidden relationship requested through the fields of an included type is left out",
         %{post: post, comment: comment} do
      response =
        get(
          Domain,
          "/posts/#{post.id}?include=comments&fields[comment]=body,author",
          status: 200,
          actor: @non_admin
        )

      assert %{"included" => [included_comment]} = response.resp_body
      assert included_comment["id"] == comment.id
      assert included_comment["attributes"] == %{"body" => "Nice"}
      refute Map.has_key?(included_comment["relationships"]["author"], "data")
    end

    test "a forbidden relationship with always_include_linkage is left out", %{review: review} do
      response = get(Domain, "/reviews/#{review.id}", status: 200, actor: @non_admin)

      assert %{"data" => %{"relationships" => %{"author" => author}}} = response.resp_body
      refute Map.has_key?(author, "data")
      refute Map.has_key?(response.resp_body, "included")
    end

    test "permitted relationships are still included", %{post: post, author: author, note: note} do
      response =
        get(Domain, "/posts/#{post.id}?include=author,notes", status: 200, actor: @admin)

      %{"included" => included, "data" => %{"relationships" => relationships}} =
        response.resp_body

      assert relationships["author"]["data"] == %{"type" => "author", "id" => author.id}
      assert relationships["notes"]["data"] == [%{"type" => "note", "id" => note.id}]

      assert included |> Enum.map(&{&1["type"], &1["id"]}) |> Enum.sort() ==
               Enum.sort([{"author", author.id}, {"note", note.id}])
    end
  end
end
