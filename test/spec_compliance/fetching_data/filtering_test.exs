defmodule AshJsonApiTest.FetchingData.Filtering do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  defmodule Narrative do
    use Ash.Type.Enum,
      values: [
        :novel,
        :legend,
        :myth,
        :fable,
        :tale,
        :action,
        :plot
      ]
  end

  defmodule Author do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.Filtering.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      routes do
        base("/authors")
        get(:read, primary?: true)
        index(:read)
      end

      includes posts: []
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
      has_many(:posts, AshJsonApiTest.FetchingData.Filtering.Post, public?: true)
    end

    aggregates do
      count(:post_count, :posts, public?: true)
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.Filtering.Domain,
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
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        accept([:name, :author_id, :narratives])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)

      attribute(:narratives, {:array, Narrative},
        default: [],
        public?: true
      )
    end

    relationships do
      belongs_to(:author, Author) do
        public?(true)
        attribute_writable?(true)
      end
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

  # JSON:API 1.0 Specification
  # --------------------------
  # The filter query parameter is reserved for filtering data. Servers and clients SHOULD use this key for filtering operations.
  # --------------------------
  describe "filter query param" do
    @describetag :spec_may
    test "key-value filter" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar"})
        |> Ash.create!()

      _conn =
        Domain
        |> get("/posts?filter[name]=foo", status: 200)
        |> assert_valid_resource_objects("post", [post.id])
        |> assert_invalid_resource_objects("post", [post2.id])
    end

    test "equals/not_equals filter" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar"})
        |> Ash.create!()

      _conn =
        Domain
        |> get("/posts?filter[name][equals]=foo", status: 200)
        |> assert_valid_resource_objects("post", [post.id])
        |> assert_invalid_resource_objects("post", [post2.id])

      _conn =
        Domain
        |> get("/posts?filter[name][not_equals]=foo", status: 200)
        |> assert_valid_resource_objects("post", [post2.id])
        |> assert_invalid_resource_objects("post", [post.id])
    end

    test "in/not_in filter" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", narratives: [:novel, :legend]})
        |> Ash.create!()

      post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar", narratives: [:legend]})
        |> Ash.create!()

      # single value
      # _conn =
      #   Domain
      #   |> get("/filter[narratives][in]=novel",
      #     status: 200
      #   )
      #   |> assert_valid_resource_objects("post", [post.id, post2.id])

      # comma-separated
      # _conn =
      #   Domain
      #   |> get("/posts?filter[narratives][in]=novel,legend",
      #     status: 200
      #   )
      #   |> assert_valid_resource_objects("post", [post.id, post2.id])

      # PHP-style array
      # _conn =
      #   Domain
      #   |> get("/posts?filter[narratives][in][]=novel&filter[narratives][in][]=legend",
      #     status: 200
      #   )
      #   |> assert_valid_resource_objects("post", [post.id, post2.id])

      # nested array
      # _conn =
      #   Domain
      #   |> get("/posts?filter[narratives][in][][]=novel ",
      #     status: 200
      #   )
      #   |> assert_valid_resource_objects("post", [post.id, post2.id])

      # bracket notation
      # _conn =
      #   Domain
      #   |> get("/posts?filter[narratives][in]=[novel,legend]", status: 200)
      #   |> assert_valid_resource_objects("post", [post.id, post2.id])

      _conn =
        Domain
        |> get("/posts?filter[narratives][in][0]=novel&filter[narratives][in][1]=legend",
          status: 200
        )
        |> assert_valid_resource_objects("post", [post.id, post2.id])

      # _conn =
      #   Domain
      #   |> get("/posts?filter[narratives][not_in]=novel,legend", status: 200)
      #   |> assert_valid_resource_objects("post", [])
    end

    test "is_nil filter" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.create!()

      _conn =
        Domain
        |> get("/posts?filter[name][is_nil]=false", status: 200)
        |> assert_valid_resource_objects("post", [post.id])
        |> assert_invalid_resource_objects("post", [post2.id])

      _conn =
        Domain
        |> get("/posts?filter[name][is_nil]=true", status: 200)
        |> assert_valid_resource_objects("post", [post2.id])
        |> assert_invalid_resource_objects("post", [post.id])
    end

    test "ordering filters" do
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "Tyler Durden"})
        |> Ash.create!()

      author2 =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "John Doe"})
        |> Ash.create!()

      _post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", author_id: author.id})
        |> Ash.create!()

      _post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar", author_id: author.id})
        |> Ash.create!()

      _conn =
        Domain
        |> get("/authors?filter[post_count][gt]=1", status: 200)
        |> assert_valid_resource_objects("author", [author.id])
        |> assert_invalid_resource_objects("author", [author2.id])

      _conn =
        Domain
        |> get("/authors?filter[post_count][gte]=2", status: 200)
        |> assert_valid_resource_objects("author", [author.id])
        |> assert_invalid_resource_objects("author", [author2.id])

      _conn =
        Domain
        |> get("/authors?filter[post_count][lt]=1", status: 200)
        |> assert_valid_resource_objects("author", [author2.id])
        |> assert_invalid_resource_objects("author", [author.id])

      _conn =
        Domain
        |> get("/authors?filter[post_count][lte]=0", status: 200)
        |> assert_valid_resource_objects("author", [author2.id])
        |> assert_invalid_resource_objects("author", [author.id])
    end
  end

  # Note: JSON:API is agnostic about the strategies supported by a server. The filter query parameter can be used as the basis for any number of filtering strategies.
end
