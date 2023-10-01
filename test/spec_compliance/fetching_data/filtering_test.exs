defmodule AshJsonApiTest.FetchingData.Filtering do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  defmodule Author do
    use Ash.Resource,
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
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
    end

    relationships do
      has_many(:posts, AshJsonApiTest.FetchingData.Filtering.Post)
    end

    aggregates do
      count(:post_count, :posts)
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
      end
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        accept([:name, :author_id])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
    end

    relationships do
      belongs_to(:author, Author) do
        attribute_writable?(true)
      end
    end
  end

  defmodule Registry do
    use Ash.Registry

    entries do
      entry(Author)
      entry(Post)
    end
  end

  defmodule Api do
    use Ash.Api,
      extensions: [
        AshJsonApi.Api
      ]

    json_api do
      router(AshJsonApiTest.FetchingData.Filtering.Router)
    end

    resources do
      registry(Registry)
    end
  end

  defmodule Router do
    use AshJsonApi.Api.Router, registry: Registry, api: Api
  end

  import AshJsonApi.Test

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The filter query parameter is reserved for filtering data. Servers and clients SHOULD use this key for filtering operations.
  # --------------------------
  describe "filter query param" do
    test "key-value filter" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar"})
        |> Api.create!()

      _conn =
        Api
        |> get("/posts?filter[name]=foo", status: 200)
        |> assert_valid_resource_objects("post", [post.id])
        |> assert_invalid_resource_objects("post", [post2.id])
    end

    test "equals/not_equals filter" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar"})
        |> Api.create!()

      _conn =
        Api
        |> get("/posts?filter[name][equals]=foo", status: 200)
        |> assert_valid_resource_objects("post", [post.id])
        |> assert_invalid_resource_objects("post", [post2.id])

      _conn =
        Api
        |> get("/posts?filter[name][not_equals]=foo", status: 200)
        |> assert_valid_resource_objects("post", [post2.id])
        |> assert_invalid_resource_objects("post", [post.id])
    end

    test "ordering filters" do
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "Tyler Durden"})
        |> Api.create!()

      author2 =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "John Doe"})
        |> Api.create!()

      _post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", author_id: author.id})
        |> Api.create!()

      _post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar", author_id: author.id})
        |> Api.create!()

      _conn =
        Api
        |> get("/authors?filter[post_count][gt]=1", status: 200)
        |> assert_valid_resource_objects("author", [author.id])
        |> assert_invalid_resource_objects("author", [author2.id])

      _conn =
        Api
        |> get("/authors?filter[post_count][gte]=2", status: 200)
        |> assert_valid_resource_objects("author", [author.id])
        |> assert_invalid_resource_objects("author", [author2.id])

      _conn =
        Api
        |> get("/authors?filter[post_count][lt]=1", status: 200)
        |> assert_valid_resource_objects("author", [author2.id])
        |> assert_invalid_resource_objects("author", [author.id])

      _conn =
        Api
        |> get("/authors?filter[post_count][lte]=0", status: 200)
        |> assert_valid_resource_objects("author", [author2.id])
        |> assert_invalid_resource_objects("author", [author.id])
    end
  end

  # Note: JSON:API is agnostic about the strategies supported by a server. The filter query parameter can be used as the basis for any number of filtering strategies.
end
