defmodule AshJsonApi.ContentNegotiationTest do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0
  @moduletag :skip

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

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
    use AshJsonApi.Api, authorize?: false

    resources([Post, Author])
  end

  import AshJsonApi.Test

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # Clients MUST send all JSON:API data in request documents with the header Content-Type: application/vnd.api+json without any media type parameters.
  # --------------------------
  describe "Client sending request Content-Type header" do
    # N/A
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # Clients that include the JSON:API media type in their Accept header MUST specify the media type there at least once without any media type parameters.
  # --------------------------
  describe "Client sending request Accept header" do
    # N/A
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # Clients MUST ignore any parameters for the application/vnd.api+json media type received in the Content-Type header of response documents.
  # --------------------------
  describe "Client processing response Content-Type header" do
    # N/A
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # Servers MUST send all JSON:API data in response documents with the header Content-Type: application/vnd.api+json without any media type parameters.
  # --------------------------
  describe "Server sending Content-Type header in response" do
    # NOTE: This behavior is asserted as part of ALL responses - see `AshJsonApi.Test.get/3`
    test "individual resource" do
      {:ok, post} = Api.create(Post, attributes: %{name: "Hamlet"})

      Api
      |> get("/posts/#{post.id}")
      |> assert_response_header_equals("content-type", "application/vnd.api+json")
    end
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # Servers MUST respond with a 415 Unsupported Media Type status code if a request specifies the header Content-Type: application/vnd.api+json with any media type parameters.
  # --------------------------
  describe "Server sending 415 Unsupported Media Type" do
    test "request Content-Type header is not present" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", exclude_req_content_type_header: true, status: 200)
    end

    test "request Content-Type header present but nil" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_content_type_header: nil, status: 200)
    end

    test "request Content-Type header present but blank" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_content_type_header: "", status: 200)
    end

    test "request Content-Type header is JSON:API" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_content_type_header: "application/vnd.api+json",
        status: 200
      )
    end

    test "request Content-Type header is JSON:API modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_content_type_header:
          "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\"",
        status: 200
      )
    end

    test "request Content-Type header includes JSON:API and JSON:API modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_content_type_header:
          "application/vnd.api+json, application/vnd.api+json; charset=test",
        status: 415
      )
    end

    test "request Content-Type header includes two instances of JSON:API modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_content_type_header:
          "application/vnd.api+json; charset=test, application/vnd.api+json; charset=test",
        status: 415
      )
    end

    test "request Content-Type header is a random value" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_content_type_header: "foo", status: 415)
    end

    test "request Content-Type header is a */*" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_content_type_header: "*/*", status: 200)
    end

    test "request Content-Type header is a */* modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_content_type_header: "*/*;q=0.8", status: 200)
    end

    test "request Content-Type header is a valid media type other than JSON:API" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_content_type_header: "application/vnd.api+json; charset=\"utf-8\"",
        status: 415
      )
    end
  end

  @tag :spec_must
  # JSON:API 1.0 Specification
  # --------------------------
  # Servers MUST respond with a 406 Not Acceptable status code if a request’s Accept header contains the JSON:API media type and all instances of that media type are modified with media type parameters.
  # --------------------------
  describe "Server sending 406 Not Acceptable" do
    test "request Accept header is not present" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", exclude_req_accept_header: true, status: 200)
    end

    test "request Accept header present but blank" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_accept_header: "", status: 200)
    end

    test "request Accept header present but nil" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_accept_header: nil, status: 200)
    end

    test "request Accept header is JSON:API" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_accept_header: "application/vnd.api+json", status: 200)
    end

    test "request Accept header is JSON:API modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_accept_header:
          "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\"",
        status: 200
      )
    end

    test "request Accept header includes JSON:API and JSON:API modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_accept_header: "application/vnd.api+json, application/vnd.api+json; charset=test",
        status: 200
      )
    end

    test "request Accept header includes two instances of JSON:API modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_accept_header:
          "application/vnd.api+json; charset=test, application/vnd.api+json; charset=test",
        status: 406
      )
    end

    test "request Accept header is a random value" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_accept_header: "foo", status: 200)
    end

    test "request Accept header is a */*" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_accept_header: "*/*", status: 200)
    end

    test "request Accept header is a */* modified with a param" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}", req_accept_header: "*/*;q=0.8", status: 200)
    end

    test "request Accept header is a valid media type other than JSON:API" do
      {:ok, post} = Api.create(Post, attributes: %{name: "foo"})

      get(Api, "/posts/#{post.id}",
        req_accept_header: "application/vnd.api+json; charset=\"utf-8\"",
        status: 406
      )
    end
  end
end
