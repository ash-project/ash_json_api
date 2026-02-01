# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiTest.FetchingData.Sorting do
  use ExUnit.Case

  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY choose to support requests to sort resource collections according to one or more criteria (“sort fields”).
  # An endpoint MAY support requests to sort the primary data with a sort query parameter.
  # The value for sort MUST represent sort fields.
  # NOTE: I lumped these three statements all together because they seem super connected
  # --------------------------
  describe "sort fields" do
    @describetag :spec_may
    # Note: Although recommended, sort fields do not necessarily need to correspond to resource attribute and association names.
    # Note: It is recommended that dot-separated (U+002E FULL-STOP, “.”) sort fields be used to request sorting based upon relationship attributes. For example, a sort field of author.name could be used to request that the primary data be sorted based upon the name attribute of the author relationship.
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # An endpoint MAY support multiple sort fields by allowing comma-separated (U+002C COMMA, “,”) sort fields. Sort fields SHOULD be applied in the order specified.
  # --------------------------
  describe "multiple sort fields" do
    @describetag :spec_may
    # GET /people?sort=age
  end

  # I put this as "may" because sorting is an optional feature
  # JSON:API 1.0 Specification
  # --------------------------
  # The sort order for each sort field MUST be ascending unless it is prefixed with a minus (U+002D HYPHEN-MINUS, “-“), in which case it MUST be descending.
  # --------------------------
  describe "sort order logic" do
    @describetag :spec_may
    # GET /articles?sort=-created,title
    # The above example should return the newest articles first. Any articles created on the same date will then be sorted by their title in ascending alphabetical order.
  end

  # I put this as "may" because sorting is an optional feature
  # JSON:API 1.0 Specification
  # --------------------------
  # If the server does not support sorting as specified in the query parameter sort, it MUST return 400 Bad Request.
  # --------------------------
  describe "400 Bad Request" do
    @describetag :spec_may
  end

  # I put this as "may" because sorting is an optional feature
  # JSON:API 1.0 Specification
  # --------------------------
  # If sorting is supported by the server and requested by the client via query parameter sort, the server MUST return elements of the top-level data array of the response ordered according to the criteria specified.
  # --------------------------
  describe "return order of elements" do
    @describetag :spec_may
    # This seems redundant
  end

  # Figure out how to make sure this applies to all types of requests - not just to an index route
  # Note: This section applies to any endpoint that responds with a resource collection as primary data, regardless of the request type.
end
