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
