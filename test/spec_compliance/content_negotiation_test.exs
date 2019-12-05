defmodule AshJsonApi.ContentNegotiationTest do
  use ExUnit.Case
  import AshJsonApi.Test
  @module_tag :json_api_spec_1_0

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
      defaults([:read, :create],
        rules: [allow(:static, result: true)]
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
      defaults([:read, :create],
        rules: [allow(:static, result: true)]
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

    api do
      resources([Post, Author])
    end
  end

  @tag :spec_must
  describe "Servers MUST send all JSON:API data in response documents with the header Content-Type: application/vnd.api+json without any media type parameters." do
    test "individual resource" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "Hamlet"}})

      # TODO: Content-Type is in capital case on the JSON:API spec, but elixir recommends we use lower case...
      get(Api, "/posts/#{post.id}", resp_headers_include: {"Content-Type", "application/vnd.api+json"})
    end
  end

  @tag :spec_must
  describe "Servers MUST respond with a 415 Unsupported Media Type status code if a request specifies the header Content-Type: application/vnd.api+json with any media type parameters." do
    test "request Content-Type header is JSON:API" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_content_type_header: "application/vnd.api+json", status: 200)
    end

    test "request Content-Type header is JSON:API with a profile param" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_content_type_header: "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\"", status: 200)
    end

    test "request Content-Type header is not present" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", exclude_req_content_type_header: true, status: 415)
    end

    test "request Content-Type header is blank" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_content_type_header: "", status: 415)
    end

    test "request Content-Type header is a random value" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_content_type_header: "foo", status: 415)
    end

    test "request Content-Type header is a valid media type" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_content_type_header: "text/html", status: 415)
    end

    test "request Content-Type header is JSON:API with a non-profile param" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_content_type_header: "application/vnd.api+json; charset=\"utf-8\"", status: 415)
    end
  end

  @tag :spec_must
  describe "Servers MUST respond with a 406 Not Acceptable status code if a request’s Accept header contains the JSON:API media type and all instances of that media type are modified with media type parameters." do
    test "request Accept header is JSON:API" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_accept_header: "application/vnd.api+json", status: 200)
    end

    # TODO: test suite blows up with its real name so I renamed it to foo
    # test "request Accept header is JSON:API with a profile param" do
    test "foo" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_accept_header: "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\"", status: 200)
    end

    test "request Accept header is not present" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", exclude_req_accept_header: true, status: 200)
    end

    test "request Accept header is blank" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_accept_header: "", status: 406)
    end

    test "request Accept header is a random value" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_accept_header: "foo", status: 406)
    end

    test "request Accept header is a valid media type" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_accept_header: "text/html", status: 406)
    end

    # TODO: test suite blows up with its real name so I renamed it to bar
    # test "request Accept header is JSON:API with a non-profile param" do
    test "bar" do
      # Create a post
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo"}})

      get(Api, "/posts/#{post.id}", req_accept_header: "application/vnd.api+json; charset=\"utf-8\"", status: 406)
    end
  end
end
