defmodule AshJsonApiTest.FetchingData.SparseFieldsets do
  use ExUnit.Case
  use Plug.Test
  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # A client MAY request that an endpoint return only specific fields in the response on a per-type basis by including a fields[TYPE] parameter.
  # --------------------------
  describe "fields[TYPE] parameter request" do
    # N/A
  end

  # I put this as "may" because sparse fieldsets is an optional feature
  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The value of the fields parameter MUST be a comma-separated (U+002C COMMA, “,”) list that refers to the name(s) of the fields to be returned.
  # --------------------------
  describe "fields[TYPE] parameter value" do
    # Do we want to implement this?
    # GET /articles?include=author&fields[articles]=title,body&fields[people]=name
  end

  # I put this as "may" because sparse fieldsets is an optional feature
  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # If a client requests a restricted set of fields for a given resource type, an endpoint MUST NOT include additional fields in resource objects of that type in its response.
  # --------------------------
  describe "No additional fields returned beyond the fields specified in the fields[TYPE] parameter" do
    # This is testing a negative, which is hard to do.
    # Perhaps this test is better done as part of a higher level test suite validation that runs every single time a request in the test suite is made (and validates against the JSON:API schema as one step)?
    # GET /articles?include=author&fields[articles]=title,body&fields[people]=name
  end

  # TODO: Figure out what to do about this note about unencoded characters
  # Note: The above example URI shows unencoded [ and ] characters simply for readability. In practice, these characters must be percent-encoded, per the requirements in RFC 3986.

  # TODO: Figure out what to do about this note about sparse fieldsets with non-GET/INDEX requests...
  # Note: This section applies to any endpoint that responds with resources as primary or included data, regardless of the request type. For instance, a server could support sparse fieldsets along with a POST request to create a resource.
end
