defmodule AshJsonApiTest.FetchingData.FetchingRelationships do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0

  defmodule Author do
    use Ash.Resource, name: "authors", type: "author"
    use AshJsonApi.JsonApiResource
    use Ash.DataLayer.Ets, private?: true

    json_api do
      routes do
        get(:default)
        index(:default)
      end

      fields [:name]
    end

    actions do
      read(:default,
        rules: [
          authorize_if: always()
        ]
      )

      create(:default,
        rules: [
          authorize_if: always()
        ]
      )
    end

    attributes do
      attribute(:name, :string)
    end
  end

  defmodule Post do
    use Ash.Resource, name: "posts", type: "post"
    use AshJsonApi.JsonApiResource
    use Ash.DataLayer.Ets, private?: true

    json_api do
      routes do
        get(:default)
        index(:default)
      end

      fields [:name]
    end

    actions do
      read(:default,
        rules: [
          authorize_if: always()
        ]
      )

      create(:default,
        rules: [
          authorize_if: always()
        ]
      )
    end

    attributes do
      attribute(:name, :string)
    end

    relationships do
      belongs_to(:author, Author)
    end
  end

  defmodule Api do
    use Ash.Api
    use AshJsonApi.Api

    resources([Post, Author])
  end

  import AshJsonApi.Test

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST support fetching relationship data for every relationship URL provided as a self link as part of a relationship’s links object.
  # --------------------------
  describe "relationship links" do
    # I'm not sure how to test this...
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST respond to a successful request to fetch a relationship with a 200 OK response.
  # --------------------------
  describe "200 OK response." do
    test "empty to-one relationship" do
      # Create a post without an author
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}/relationships/author", status: 200)
    end

    test "empty to-many relationship" do
      # Create a post without comments
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}/relationships/comments", status: 200)
    end

    test "non-empty to-one relationship" do
      # Create a post with an author
      {:ok, author} = Api.create(Author, %{attributes: %{name: "foo"}})

      {:ok, post} =
        Api.create(Post, %{attributes: %{name: "foo"}}, %{
          relationships: %{author: author}
        })

      get(Api, "/posts/#{post.id}/relationships/author", status: 200)
    end

    test "non-empty to-many relationship" do
      # Create a post with an author
      {:ok, comment_1} = Api.create(Comment, %{attributes: %{text: "First Comment"}})
      {:ok, comment_2} = Api.create(Comment, %{attributes: %{text: "Second Comment"}})

      {:ok, post} =
        Api.create(Post, %{attributes: %{name: "foo"}}, %{
          relationships: %{comments: [comment_1, comment_2]}
        })

      get(Api, "/posts/#{post.id}/relationships/comments", status: 200)
    end
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # The primary data in the response document MUST match the appropriate value for resource linkage, as described above for relationship objects.
  # --------------------------
  describe "primary data resource linkage" do
  end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The top-level links object MAY contain self and related links, as described above for relationship objects.
  # --------------------------
  describe "top-level links object" do
    # Do we want to implement this?
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST return 404 Not Found when processing a request to fetch a relationship link URL that does not exist.
  # --------------------------
  describe "404 Not Found" do
    # Note: This can happen when the parent resource of the relationship does not exist. For example, when /articles/1 does not exist, request to /articles/1/relationships/tags returns 404 Not Found.
    # If a relationship link URL exists but the relationship is empty, then 200 OK MUST be returned, as described above.
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
end
