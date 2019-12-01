defmodule AshJsonApi.ContentNegotiationTest do
  use ExUnit.Case
  use Plug.Test
  @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  @tag :spec_must
  describe "Servers MUST send all JSON:API data in response documents with the header Content-Type: application/vnd.api+json without any media type parameters." do
    test "individual resource" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn(:get, "/posts/#{post.id}")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the header
      # Should there be a semi colon at the end?
      # Should we include the charset?
      assert Enum.member?(conn.resp_headers, {"Content-Type", "application/vnd.api+json;"})
    end
  end

  describe "Servers MUST respond with a 415 Unsupported Media Type status code if a request specifies the header Content-Type: application/vnd.api+json with any media type parameters." do
    test "request Content-Type header is the JSON:API media type" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn = conn
        |> put_req_header("content-type", "application/vnd.api+json;")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 200
    end

    # test "request Content-Type header is the JSON:API media type along with a profile parameter" do
    #   # Create a post
    #   {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

    #   # Create a test connection
    #   conn = build_conn()
    #     |> put_req_header("Content-Type", "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\"")
    #     |> get("/posts/#{post.id}")

    #   # Invoke the plug
    #   conn = AshJsonApi.Test.Router.call(conn, @router_opts)

    #   # Assert the response has been senet
    #   assert conn.state == :sent

    #   # Assert the response
    #   assert json_response(conn, 200)
    # end

    # test "request Content-Type header is not present" do
    #   # TODO: remove content header from request
    #   conn = get(conn, "/api/schools/1")
    #   assert json_response(conn, 415)
    # end

    # test "request Content-Type header is blank" do
    #   content_header = ""
    #   # TODO: set content header variable on reuest
    #   conn = get(conn, "/api/schools/1")
    #   assert json_response(conn, 415)
    # end

    # test "request Content-Type header is a random value" do
    #   content_header = "foo"
    #   # TODO: set content header variable on reuest
    #   conn = get(conn, "/api/schools/1")
    #   assert json_response(conn, 415)
    # end

    # test "request Content-Type header is a real media type other than the JSON:API media type" do
    #   content_header = "text/html"
    #   # TODO: set content header variable on reuest
    #   conn = get(conn, "/api/schools/1")
    #   assert json_response(conn, 415)
    # end

    # test "request Content-Type header is the JSON:API media type along with a parameter other than profile" do
    #   content_header = "application/vnd.api+json; charset=\"utf-8\""
    #   # TODO: set content header variable on reuest
    #   conn = get(conn, "/api/schools/1")
    #   assert json_response(conn, 415)
    # end
  end

  describe "Servers MUST respond with a 406 Not Acceptable status code if a request’s Accept header contains the JSON:API media type and all instances of that media type are modified with media type parameters." do

  end


  describe "Content Header of Request" do
    # test "when set to the JSON:API media type" do
    #   # Create a post
    #   {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

    #   # Create a test connection
    #   conn = conn(:get, "/posts/#{post.id}")

    #   # Invoke the plug
    #   conn = AshJsonApi.Test.Router.call(conn, @router_opts)

    #   # Assert the response and status
    #   assert conn.state == :sent
    #   assert conn.status == 200



  end
  # describe "Accept Header of Request" do
  #   test "when set to the JSON:API media type" do
  #     accept_header = "application/vnd.api+json"
  #     # TODO: set accept header variable on reuest
  #     conn = get(conn, "/api/schools/1")
  #     assert json_response(conn, 200)
  #   end
  #   test "when set to the JSON:API media type along with a profile parameter" do
  #     accept_header = "application/vnd.api+json; charset=\"utf-8\""
  #     # TODO: set accept header variable on reuest
  #     conn = get(conn, "/api/schools/1")
  #     assert json_response(conn, 200)
  #   end
  #   test "when not present" do
  #     # TODO: remove accept header from request
  #     conn = get(conn, "/api/schools/1")
  #     assert json_response(conn, 200)
  #   end
  #   test "when blank" do
  #     accept_header = ""
  #     # TODO: set accept header variable on reuest
  #     conn = get(conn, "/api/schools/1")
  #     assert json_response(conn, 406)
  #   end
  #   test "when set to a random value" do
  #     accept_header = "foo"
  #     # TODO: set accept header variable on reuest
  #     conn = get(conn, "/api/schools/1")
  #     assert json_response(conn, 406)
  #   end
  #   test "when set to a real media type other than the JSON:API media type" do
  #     accept_header = "text/html"
  #     # TODO: set accept header variable on reuest
  #     conn = get(conn, "/api/schools/1")
  #     assert json_response(conn, 406)
  #   end
  #   test "when set to the JSON:API media type along with a parameter other than profile" do
  #     accept_header = "application/vnd.api+json; charset=\"utf-8\""
  #     # TODO: set content header variable on reuest
  #     conn = get(conn, "/api/schools/1")
  #     assert json_response(conn, 406)
  #   end
  # end
end
