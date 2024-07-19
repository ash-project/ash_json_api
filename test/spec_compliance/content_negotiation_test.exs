defmodule AshJsonApi.ContentNegotiationTest do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  defmodule Author do
    use Ash.Resource,
      domain: AshJsonApi.ContentNegotiationTest.Domain,
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
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: AshJsonApi.ContentNegotiationTest.Domain,
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
        post(:create)
      end
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
      belongs_to(:author, Author, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router(AshJsonApi.ContentNegotiationTest.Router)
    end

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
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{name: "foo"})
      |> Ash.create!()

    [post: post]
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # Clients MUST send all JSON:API data in request documents with the header Content-Type: application/vnd.api+json without any media type parameters.
  # --------------------------
  describe "Client sending request Content-Type header" do
    @describetag :spec_must
    # N/A
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # Clients that include the JSON:API media type in their Accept header MUST specify the media type there at least once without any media type parameters.
  # --------------------------
  describe "Client sending request Accept header" do
    @describetag :spec_must
    # N/A
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # Clients MUST ignore any parameters for the application/vnd.api+json media type received in the Content-Type header of response documents.
  # --------------------------
  describe "Client processing response Content-Type header" do
    @describetag :spec_must
    # N/A
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # Servers MUST send all JSON:API data in response documents with the header Content-Type: application/vnd.api+json without any media type parameters.
  # --------------------------
  describe "Server sending Content-Type header in response" do
    @describetag :spec_must
    # NOTE: This behavior is asserted as part of ALL responses - see `AshJsonApi.Test.get/3`
    test "individual resource", %{post: post} do
      Domain
      |> get("/posts/#{post.id}")
      |> assert_response_header_equals("content-type", "application/vnd.api+json")
    end
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # Servers MUST respond with a 415 Unsupported Media Type status code if a request specifies the header Content-Type: application/vnd.api+json with any media type parameters.
  # --------------------------
  describe "Server sending 415 Unsupported Media Type" do
    @describetag :spec_must
    @create_body %{
      data: %{
        type: "post",
        attributes: %{}
      }
    }

    @tag :skip
    # Plug.Test doesn't let you send a body w/o a content-type
    test "request Content-Type header is not present" do
      post(Domain, "/posts", @create_body, exclude_req_content_type_header: true, status: 201)
    end

    @tag :skip
    # for the same reason as above
    test "request Content-Type header present but blank" do
      post(Domain, "/posts", @create_body, req_content_type_header: "", status: 201)
    end

    test "request Content-Type header present but nil" do
      post(Domain, "/posts", @create_body, req_content_type_header: nil, status: 201)
    end

    test "request Content-Type header is JSON:API" do
      post(Domain, "/posts", @create_body,
        req_content_type_header: "application/vnd.api+json",
        status: 201
      )
    end

    test "request Content-Type header is JSON:API modified with a param" do
      post(Domain, "/posts", @create_body,
        req_content_type_header:
          "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\"",
        status: 201
      )
    end

    test "request Content-Type header includes JSON:API and JSON:API modified with a param" do
      assert_raise Plug.Parsers.UnsupportedMediaTypeError, fn ->
        post(Domain, "/posts", @create_body,
          req_content_type_header:
            "application/vnd.api+json, application/vnd.api+json; charset=test"
        )
      end
    end

    @tag capture_log: true
    test "request Content-Type header includes two instances of JSON:API modified with a param" do
      post(Domain, "/posts", @create_body,
        req_content_type_header:
          "application/vnd.api+json; charset=test, application/vnd.api+json; charset=test",
        status: 406
      )
    end

    test "request Content-Type header is a random value" do
      assert_raise Plug.Parsers.UnsupportedMediaTypeError, fn ->
        post(Domain, "/posts", @create_body, req_content_type_header: "foo")
      end
    end

    @tag capture_log: true
    test "request Content-Type header is a valid media type other than JSON:API" do
      post(Domain, "/posts", @create_body,
        req_content_type_header: "application/vnd.api+json; charset=\"utf-8\"",
        status: 406
      )
    end
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # Servers MUST respond with a 406 Not Acceptable status code if a request’s Accept header contains the JSON:API media type and all instances of that media type are modified with media type parameters.
  # --------------------------
  describe "Server sending 406 Not Acceptable" do
    @describetag :spec_must
    test "request Accept header is not present", %{post: post} do
      get(Domain, "/posts/#{post.id}", exclude_req_accept_header: true, status: 200)
    end

    test "request Accept header present but blank", %{post: post} do
      get(Domain, "/posts/#{post.id}", req_accept_header: "", status: 200)
    end

    test "request Accept header present but nil", %{post: post} do
      get(Domain, "/posts/#{post.id}", req_accept_header: nil, status: 200)
    end

    test "request Accept header is JSON:API", %{post: post} do
      get(Domain, "/posts/#{post.id}", req_accept_header: "application/vnd.api+json", status: 200)
    end

    test "request Accept header is JSON:API modified with a param", %{post: post} do
      get(Domain, "/posts/#{post.id}",
        req_accept_header:
          "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\"",
        status: 200
      )
    end

    test "request Accept header includes JSON:API and JSON:API modified with a param", %{
      post: post
    } do
      get(Domain, "/posts/#{post.id}",
        req_accept_header: "application/vnd.api+json, application/vnd.api+json; charset=test",
        status: 200
      )
    end

    @tag capture_log: true
    test "request Accept header includes two instances of JSON:API modified with a param", %{
      post: post
    } do
      get(Domain, "/posts/#{post.id}",
        req_accept_header:
          "application/vnd.api+json; charset=test, application/vnd.api+json; charset=test",
        status: 415
      )
    end

    test "request Accept header is a random value", %{post: post} do
      get(Domain, "/posts/#{post.id}", req_accept_header: "foo", status: 200)
    end

    test "request Accept header is a */*", %{post: post} do
      get(Domain, "/posts/#{post.id}", req_accept_header: "*/*", status: 200)
    end

    test "request Accept header is a */* modified with a param", %{post: post} do
      get(Domain, "/posts/#{post.id}", req_accept_header: "*/*;q=0.8", status: 200)
    end

    @tag capture_log: true
    test "request Accept header is a valid media type other than JSON:API", %{post: post} do
      get(Domain, "/posts/#{post.id}",
        req_accept_header: "application/vnd.api+json; charset=\"utf-8\"",
        status: 415
      )
    end

    test "request Accept header is a valid media type other than JSON:API with bypass config", %{
      post: post
    } do
      Application.put_env(:ash_json_api, :allow_all_media_type_params?, true)

      get(Domain, "/posts/#{post.id}",
        req_accept_header: "application/vnd.api+json; charset=\"utf-8\"",
        status: 200
      )

      Application.put_env(:ash_json_api, :allow_all_media_type_params?, nil)
    end
  end
end
