defmodule AshJsonApiTest.FetchingData do
  use ExUnit.Case
  use Plug.Test
  @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  describe "Fetching Resources" do
    # A server MUST support fetching resource data for every URL provided as:

    # a self link as part of the top-level links object
    # a self link as part of a resource-level links object
    # a related link as part of a relationship-level links object

    # What does this mean - that all the URLS contained in a response are valid API urls?

    # describe "200 OK" do
    test "A server MUST respond to a successful request to fetch an individual resource with a 200 OK response." do
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

    # test "A server MUST respond to a successful request to fetch a resource collection with an array of resource objects or an empty array ([]) as the response document’s primary data." do

    # end

    # test "A server MUST respond to a successful request to fetch an individual resource with a resource object or null provided as the response document’s primary data." do
    #   # confused as to why this is a 200 and not 404
    # end
    # end

    # describe "404 Not Found" do
    #   test "A server MUST respond with 404 Not Found when processing a request to fetch a single resource that does not exist, except when the request warrants a 200 OK response with null as the primary data (as described above)." do

    #   end
    # end

    # describe "Other Responses" do
    #   test "A server MAY respond with other HTTP status codes." do

    #   end

    #   test "A server MAY include error details with error responses." do

    #   end

    #   test "A server MUST prepare responses, and a client MUST interpret responses, in accordance with HTTP semantics." do

    #   end
    # end
  end

  # describe "Fetching Relationships" do
  #   describe "200 OK" do
  #     test "A server MUST respond to a successful request to fetch a relationship with a 200 OK response." do

  #     end

  #     test "The primary data in the response document MUST match the appropriate value for resource linkage, as described above for relationship objects." do

  #     end

  #     test "The top-level links object MAY contain self and related links, as described above for relationship objects." do

  #     end
  #   end

  #   describe "404 Not Found" do
  #     test "A server MUST return 404 Not Found when processing a request to fetch a relationship link URL that does not exist." do
  #       # Note: This can happen when the parent resource of the relationship does not exist. For example, when /articles/1 does not exist, request to /articles/1/relationships/tags returns 404 Not Found.
  #       # If a relationship link URL exists but the relationship is empty, then 200 OK MUST be returned, as described above.
  #     end
  #   end

  #   describe "Other Responses" do
  #     @tag :spec_may
  #     test "A server MAY respond with other HTTP status codes." do

  #     end

  #     test "A server MAY include error details with error responses." do

  #     end

  #     test "A server MUST prepare responses in accordance with HTTP semantics." do

  #     end
  #   end
  # end

  # describe "Inclusion of Related Resources" do

  # end

  # describe "Sparse Fieldsets" do

  # end

  # describe "Sorting" do

  # end

  # describe "Pagination" do

  # end

  # describe "Filtering" do

  # end
end
