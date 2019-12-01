defmodule AshJsonApiTest.FetchingData.FetchingResources.Ok do
  use ExUnit.Case
  use Plug.Test
  @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  describe "200 OK" do
    test "A server MUST respond to a successful request to fetch an individual resource with a 200 OK response." do
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

    test "A server MUST respond to a successful request to fetch a resource collection with a 200 OK response." do
      # Create a test connection
      conn = conn(:get, "/posts")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response and status
      assert conn.state == :sent
      assert conn.status == 200
    end

    test "A server MUST respond to a successful request to fetch a resource collection with an empty array ([]) as the response document’s primary data when there is no data." do
      # Create a test connection
      conn = conn(:get, "/posts")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response state
      assert conn.state == :sent

      # Assert the data attribute of the response body
      assert Jason.decode!(conn.resp_body)["data"] == []
    end

    test "A server MUST respond to a successful request to fetch a resource collection with an array of resource objects as the response document’s primary data when there is data." do
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

    test "A server MUST respond to a successful request to fetch an individual resource with a resource object provided as the response document’s primary data when there is data." do
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

    test "A server MUST respond to a successful request to fetch an individual resource with null provided as the response document’s primary data when there is no data" do
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
end
