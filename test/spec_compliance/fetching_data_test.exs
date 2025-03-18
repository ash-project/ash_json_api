defmodule AshJsonApiTest.FetchingData do
  use ExUnit.Case

  import Plug.Test
  import Plug.Conn
  @moduletag :json_api_spec_1_0

  # JSON:API 1.0 Specification
  # --------------------------
  # A server MUST support fetching resource data for every URL provided as:
  # a self link as part of the top-level links object
  # a self link as part of a resource-level links object
  # a related link as part of a relationship-level links object
  # --------------------------
  describe "fetching resource data" do
    @describetag :spec_must
    # What does this mean - that all the URLS contained in a response are valid API urls?
  end
end
