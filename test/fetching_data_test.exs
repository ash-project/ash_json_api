defmodule AshJsonApiTest.FetchingData do
  use ExUnit.Case
  use Plug.Test
  @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  # describe "Fetching Resources" do
    # A server MUST support fetching resource data for every URL provided as:

    # a self link as part of the top-level links object
    # a self link as part of a resource-level links object
    # a related link as part of a relationship-level links object
    # What does this mean - that all the URLS contained in a response are valid API urls?
  # end

  # describe "Fetching Relationships" do
    test "A server MUST support fetching relationship data for every relationship URL provided as a self link as part of a relationship’s links object." do
      # TODO: Figure out how to test this
    end

    # describe "200 OK" do
      describe "A server MUST respond to a successful request to fetch a relationship with a 200 OK response." do
        test "empty to-one relationship" do
          # Create a post without an author
          {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "Hamlet"}})

          # Create a test connection
          conn = conn(:get, "/posts/#{post.id}/relationships/author")

          # Invoke the plug
          conn = AshJsonApi.Test.Router.call(conn, @router_opts)

          # Assert the response and status
          assert conn.state == :sent
          assert conn.status == 200
        end

        test "empty to-many relationship" do
          # Create a post without comments
          {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "Hamlet"}})

          # Create a test connection
          conn = conn(:get, "/posts/#{post.id}/relationships/comments")

          # Invoke the plug
          conn = AshJsonApi.Test.Router.call(conn, @router_opts)

          # Assert the response and status
          assert conn.state == :sent
          assert conn.status == 200
        end

        test "non-empty to-one relationship" do
          # Create a post with an author
          {:ok, author} = Ash.create(AshJsonApi.Test.Resources.Author, %{attributes: %{name: "William Shakespeare"}})
          {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "Hamlet"}}, %{relationships: %{author: author}})

          # Create a test connection
          conn = conn(:get, "/posts/#{post.id}/relationships/author")

          # Invoke the plug
          conn = AshJsonApi.Test.Router.call(conn, @router_opts)

          # Assert the response and status
          assert conn.state == :sent
          assert conn.status == 200
        end

        test "non-empty to-many relationship" do
          # Create a post with an author
          {:ok, comment_1} = Ash.create(AshJsonApi.Test.Resources.Comment, %{attributes: %{text: "First Comment"}})
          {:ok, comment_2} = Ash.create(AshJsonApi.Test.Resources.Comment, %{attributes: %{text: "Second Comment"}})
          {:ok, post} = Ash.create(AshJsonApi.Test.Resources.Post, %{attributes: %{name: "Hamlet"}}, %{relationships: %{comments: [comment_1, comment_2]}})

          # Create a test connection
          conn = conn(:get, "/posts/#{post.id}/relationships/comments")

          # Invoke the plug
          conn = AshJsonApi.Test.Router.call(conn, @router_opts)

          # Assert the response and status
          assert conn.state == :sent
          assert conn.status == 200
        end
      end

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
