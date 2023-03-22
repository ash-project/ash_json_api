defmodule AshJsonApiTest.FetchingData.FetchingResources do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0
  @moduletag :skip

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
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
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
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
    end

    relationships do
      belongs_to(:author, Author)
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
      router(AshJsonApiTest.FetchingData.FetchingResources.Router)
    end

    resources do
      registry(Registry)
    end
  end

  defmodule Router do
    use AshJsonApi.Api.Router, registry: Registry, api: Api
  end

  import AshJsonApi.Test

  # 200 OK
  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST respond to a successful request to fetch an individual resource or resource collection with a 200 OK response.
  # --------------------------
  describe "200 OK response" do
    test "individual resource" do
      # Create a post
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      get(Api, "/posts/#{post.id}", status: 200)
    end

    test "resource collection" do
      get(Api, "/posts", status: 200)
    end
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST respond to a successful request to fetch a resource collection with an array of resource objects or an empty array ([]) as the response document’s primary data.
  # --------------------------
  describe "resource collection primary data." do
    test "data exists" do
      # Create a post
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      post2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar"})
        |> Api.create!()

      conn =
        Api
        |> get("/posts", status: 200)
        |> assert_valid_resource_objects("post", [post.id, post2.id])
    end

    test "data does NOT exist" do
      Api
      |> get("/posts", status: 200)
      |> assert_data_equals([])
    end
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST respond to a successful request to fetch an individual resource with a resource object or null provided as the response document’s primary data.
  # --------------------------
  describe "individual resource primary data." do
    test "data exists" do
      # Create a post
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      conn =
        Api
        |> get("/posts/#{post.id}", status: 200)
        |> assert_valid_resource_object("post", post.id)
        |> assert_attribute_equals("name", post.name)
    end

    test "data does NOT exist" do
      # Create a post
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      Api
      |> get("/posts/#{post.id}/author", status: 200)
      |> assert_data_equals(nil)
    end
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST respond with 404 Not Found when processing a request to fetch a single resource that does not exist, except when the request warrants a 200 OK response with null as the primary data (as described above).
  # --------------------------
  describe "404 Not Found" do
    test "individual resource without data" do
      get(Api, "/posts/#{Ecto.UUID.generate()}", status: 404)
    end
  end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY respond with other HTTP status codes.
  # --------------------------
  describe "other responses" do
    # Do we want to implement this?
    # I'm not sure how to test this...
  end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY include error details with error responses.
  # --------------------------
  describe "error responses" do
    # Do we want to implement this?
    # Need to come up with error scenarios if so
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST prepare responses in accordance with HTTP semantics.
  # --------------------------
  describe "HTTP semantics" do
    # I'm not sure how to test this...
  end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The optional links member within each resource object contains links related to the resource.
  # If present, this links object MAY contain a self link that identifies the resource represented by the resource object.
  # --------------------------
  describe "5.2.7 Resource Links" do
    setup do
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Api.create!()

      %{author: author}
    end

    test "self link is set", %{author: author} do
      conn =
        Api
        |> get("/authors/#{author.id}", status: 200)

      %{"data" => %{"links" => %{"self" => link_to_self}}} = conn.resp_body

      assert link_to_self =~ "/authors/#{author.id}"
    end
  end
end
