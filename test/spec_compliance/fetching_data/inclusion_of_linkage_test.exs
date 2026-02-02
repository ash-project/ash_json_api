# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiTest.FetchingData.InclusionOfLinkage do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0

  defmodule Author do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfLinkage.Domain,
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

      always_include_linkage([:posts])
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
      has_many(:posts, AshJsonApiTest.FetchingData.InclusionOfLinkage.Post,
        public?: true,
        destination_attribute: :author_id
      )
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfLinkage.Domain,
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

      always_include_linkage([:author, :comments])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      belongs_to(:author, Author, public?: true)

      has_many(:comments, AshJsonApiTest.FetchingData.InclusionOfLinkage.Comment, public?: true)
    end
  end

  defmodule Comment do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfLinkage.Domain,
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

      always_include_linkage([:post])
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

  describe "always_include_linkage option" do
    @describetag :spec_may
    test "resource endpoint with always_include_linkage of empty to-one relationship" do
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
                 },
                 "included" => included
               }
             } = get(Domain, "/posts/#{post.id}/", status: 200)

      assert included == []
    end

    test "resource endpoint with always_include_linkage of to-one relationship" do
      # GET /posts/1
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
                 },
                 "included" => included
               }
             } = get(Domain, "/posts/#{post.id}/", status: 200)

      assert included == []
    end

    test "resource endpoint with always_include_linkage of empty to-many relationship" do
      # GET /posts/1
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
                 },
                 "included" => included
               }
             } = get(Domain, "/posts/#{post.id}/", status: 200)

      assert included == []
    end

    test "resource endpoint with always_include_linkage of to-many relationship" do
      # GET /posts/1
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

      assert %{
               resp_body: %{
                 "data" => %{
                   "relationships" => %{
                     "comments" => %{"data" => linkage}
                   }
                 },
                 "included" => included
               }
             } = get(Domain, "/posts/#{post.id}/", status: 200)

      assert Enum.member?(linkage, %{"id" => comment1_id, "type" => "comment"})
      assert Enum.member?(linkage, %{"id" => comment2_id, "type" => "comment"})
      assert Enum.count(linkage) == 2

      assert included == []
    end
  end
end
