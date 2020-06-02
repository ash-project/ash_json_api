defmodule AshJsonApiTest.FetchingData.FetchingResources do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0
  @moduletag :skip

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
      read(:default)

      create(:default)
    end

    attributes do
      attribute(:id, :uuid, primary_key?: true)
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
      read(:default)

      create(:default)
    end

    attributes do
      attribute(:id, :uuid, primary_key?: true)
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

  # 200 OK
  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST respond to a successful request to fetch an individual resource or resource collection with a 200 OK response.
  # --------------------------
  describe "200 OK response" do
    test "individual resource" do
      # Create a post
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

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
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      Api
      |> get("/posts", status: 200)
      |> assert_data_equals([
        %{
          "attributes" => %{"name" => post.name},
          "id" => post.id,
          "links" => %{},
          "relationships" => %{},
          "type" => "post"
        }
      ])
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
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      Api
      |> get("/posts/#{post.id}", status: 200)
      |> assert_data_equals(%{
        "attributes" => %{"name" => post.name},
        "id" => post.id,
        "links" => %{},
        "relationships" => %{},
        "type" => "post"
      })
    end

    test "data does NOT exist" do
      # If the primary resource exists (ie: post) but you are trying to get access to a relationship route (such as its author) this should return a 200 with null since the post exists (even though the author does not), not a 404
      # TODO: Clear up my comment above - this is a bit tricky to explain

      # Create a post
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      Api
      |> get("/posts/#{post.id}/author", status: 200)
      |> assert_data_equals(nil)

      # Assert the data attribute of the response body
      # TODO: pass this test - it's failing I think becasue related resource routes are not working (or not configured correctly)
      # TODO: errors are printing to the terminal screen when this test runs - noise we could do without for passing tests
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
end
