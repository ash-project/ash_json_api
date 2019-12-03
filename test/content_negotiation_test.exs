defmodule AshJsonApi.ContentNegotiationTest do
  use ExUnit.Case
  use Plug.Test
  # @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  @tag :spec_must
  describe "Servers MUST send all JSON:API data in response documents with the header Content-Type: application/vnd.api+json without any media type parameters." do
    test "individual resource" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn(:get, "/posts/#{post.id}")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the header
      # Should there be a semi colon at the end?
      # Should we include the charset?
      assert Enum.member?(conn.resp_headers, {"Content-Type", "application/vnd.api+json;"})
    end
  end

  @tag :spec_must
  describe "Servers MUST respond with a 415 Unsupported Media Type status code if a request specifies the header Content-Type: application/vnd.api+json with any media type parameters." do
    test "request Content-Type header is JSON:API" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json;")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 200
    end

    test "request Content-Type header is JSON:API with a profile param" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header(
          "content-type",
          "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\""
        )

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 200
    end

    test "request Content-Type header is not present" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection with no headers
      conn = conn("get", "/posts/#{post.id}", "")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 415
    end

    test "request Content-Type header is blank" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("content-type", "")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 415
    end

    test "request Content-Type header is a random value" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("content-type", "foo")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 415
    end

    test "request Content-Type header is a valid media type" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("content-type", "text/html")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 415
    end

    test "request Content-Type header is JSON:API with a non-profile param" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json; charset=\"utf-8\"")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 415
    end
  end

  @tag :spec_must
  describe "Servers MUST respond with a 406 Not Acceptable status code if a request’s Accept header contains the JSON:API media type and all instances of that media type are modified with media type parameters." do
    test "request Accept header is JSON:API" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json;")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 200
    end

    # test "request Accept header is JSON:API with a profile param" do
    # TODO: rename this test - test suite blows up with its real name
    test "foo" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header(
          "accept",
          "application/vnd.api+json; profile=\"http://example.com/last-modified http://example.com/timestamps\""
        )

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 200
    end

    test "request Accept header is not present" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection with no headers
      conn = conn("get", "/posts/#{post.id}", "")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 200
    end

    test "request Accept header is blank" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("accept", "")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 406
    end

    test "request Accept header is a random value" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("accept", "foo")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 406
    end

    test "request Accept header is a valid media type" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("accept", "text/html")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 406
    end

    # test "request Accept header is JSON:API with a non-profile param" do
    # TODO: rename this test - test suite blows up with its real name
    test "bar" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn("get", "/posts/#{post.id}", "")

      # Set the header
      # TODO: the key of this header must be lower case for the test to not blow up, but the spec calls for capital case
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json; charset=\"utf-8\"")

      # Invoke the plug
      # conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response has been senet
      assert conn.state == :sent

      # Assert the response
      assert conn.status == 406
    end
  end
end
