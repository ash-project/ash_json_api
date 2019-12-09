defmodule AshJsonApiTest.FetchingData.Filtering do
  use ExUnit.Case
  use Plug.Test
  @moduletag :json_api_spec_1_0

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The filter query parameter is reserved for filtering data. Servers and clients SHOULD use this key for filtering operations.
  # --------------------------
  describe "filter query param" do
    # GET /people?filter=foo
    # GET /people?filter[name]=foo
    # GET /people?filter[age]=<10
  end

  # TODO: Figure out filtering strategy
  # Note: JSON:API is agnostic about the strategies supported by a server. The filter query parameter can be used as the basis for any number of filtering strategies.
end
