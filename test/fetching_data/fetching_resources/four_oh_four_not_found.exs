# TODO: Get this file to actually run when `mix test` is run...
# TODO: can we rename this module to 404NotFound or is that not allowed in Elixir?
defmodule AshJsonApiTest.FetchingData.FetchingResources.FourOhFourNotFound do
  use ExUnit.Case
  use Plug.Test
  @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  describe "404 Not Found" do
    test "A server MUST respond with 404 Not Found when processing a request to fetch a single resource that does not exist, except when the request warrants a 200 OK response with null as the primary data (as described above)." do
      # Create a test connection
      conn = conn(:get, "/posts/#{Ash.UUID.generate}")

      # Invoke the plug
      conn = AshJsonApi.Test.Router.call(conn, @router_opts)

      # Assert the response state
      assert conn.state == :sent

      # Assert the status
      assert conn.status == 404
    end
  end
end
