defmodule AshJsonApiTest.FetchingData.FetchingResources do
  use ExUnit.Case
  use Plug.Test
  @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  # 200 OK
  @tag :spec_must
  describe "A server MUST respond to a successful request to fetch an individual resource or resource collection with a 200 OK response." do
    test "individual resource" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn(:get, "/posts/#{post.id}")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 200
    end

    test "resource collection" do
      # Create a test connection
      conn = conn(:get, "/posts")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 200
    end
  end

  @tag :spec_must
  describe "A server MUST respond to a successful request to fetch a resource collection with an array of resource objects or an empty array ([]) as the response document’s primary data." do
    test "resource collection with data" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn(:get, "/posts")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response state
      assert conn.state == :sent

      # Assert the data attribute of the response body
      assert Jason.decode!(conn.resp_body)["data"] == [
               %{
                 "attributes" => %{"name" => post.name},
                 "id" => post.id,
                 "links" => %{},
                 "relationships" => %{},
                 "type" => "post"
               }
             ]
    end

    test "resource collection without data" do
      # Create a test connection
      conn = conn(:get, "/posts")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response state
      assert conn.state == :sent

      # Assert the data attribute of the response body
      assert Jason.decode!(conn.resp_body)["data"] == []
    end
  end

  @tag :spec_must
  describe "A server MUST respond to a successful request to fetch an individual resource with a resource object or null provided as the response document’s primary data." do
    test "individual resource" do
      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn(:get, "/posts/#{post.id}")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response state
      assert conn.state == :sent

      # Assert the data attribute of the response body
      assert Jason.decode!(conn.resp_body)["data"] == %{
               "attributes" => %{"name" => post.name},
               "id" => post.id,
               "links" => %{},
               "relationships" => %{},
               "type" => "post"
             }
    end

    test "individual resource without data" do
      # If the primary resource exists (ie: post) but you are trying to get access to a relationship route (such as its author) this should return a 200 with null since the post exists (even though the author does not), not a 404
      # TODO: Clear up my comment above - this is a bit tricky to explain

      # Create a post
      {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "foo"}})

      # Create a test connection
      conn = conn(:get, "/posts/#{post.id}/author")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response state
      assert conn.state == :sent

      # Assert the data attribute of the response body
      # TODO: pass this test - it's failing I think becasue related resource routes are not working (or not configured correctly)
      # TODO: is this a false positive?
      # TODO: seems like a missing "data" key will pass this test, wherewas we want to ensure the key exists and is returning the value null (not sure nil is the same as null in Elixir)
      # TODO: errors are printing to the terminal screen when this test runs - noise we could do without for passing tests
      IO.inspect(conn.resp_body)
      assert Jason.decode!(conn.resp_body)["data"] == nil
    end
  end

  # 404 Not Found
  @tag :spec_must
  describe "A server MUST respond with 404 Not Found when processing a request to fetch a single resource that does not exist, except when the request warrants a 200 OK response with null as the primary data (as described above)." do
    test "individual resource without data" do
      # TODO: come up with a better test name to distinguish this from the test above
      # Create a test connection
      conn = conn(:get, "/posts/#{Ash.UUID.generate()}")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response state
      assert conn.state == :sent

      # Assert the status
      assert conn.status == 404
    end
  end

  # Other Responses
  @tag :spec_may
  describe "A server MAY respond with other HTTP status codes." do
    # Do we want to implement this?
    # I'm not sure how to test this...
  end

  @tag :spec_may
  describe "A server MAY include error details with error responses." do
    # Do we want to implement this?
    # Need to come up with error scenarios if so
  end

  @tag :spec_must
  describe "A server MUST prepare responses in accordance with HTTP semantics." do
    # I'm not sure how to test this...
  end
end
