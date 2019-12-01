defmodule AshJsonApiTest.FetchingData.FetchingResources.OtherResponses do
  use ExUnit.Case
  use Plug.Test
  @router_opts AshJsonApi.Test.Router.init([])
  @module_tag :json_api_spec_1_0

  describe "Other Responses" do
    test "A server MAY respond with other HTTP status codes." do
      # TODO: Figure out how to test this
    end

    test "A server MAY include error details with error responses." do
      # TODO: Figure out how to test this
    end

    test "A server MUST prepare responses in accordance with HTTP semantics." do
      # TODO: Figure out how to test this
    end
  end
end
