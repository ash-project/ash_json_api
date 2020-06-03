defmodule AshJsonApiTest.FetchingData.Pagination do
  use ExUnit.Case
  use Plug.Test
  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY choose to limit the number of resources returned in a response to a subset (“page”) of the whole set available.
  # --------------------------
  describe "pagination" do
  end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY provide links to traverse a paginated data set (“pagination links”).
  # --------------------------
  describe "pagination links" do
  end

  # I put this as "may" because pagination is an optional feature
  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # Pagination links MUST appear in the links object that corresponds to a collection.
  # --------------------------
  describe "pagination links location" do
    # To paginate the primary data, supply pagination links in the top-level links object.
    # To paginate an included collection returned in a compound document, supply pagination links in the corresponding links object.
  end

  # I put this as "may" because pagination is an optional feature
  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The following keys MUST be used for pagination links:
  # first: the first page of data
  # last: the last page of data
  # prev: the previous page of data
  # next: the next page of data

  # Keys MUST either be omitted or have a null value to indicate that a particular link is unavailable.
  # --------------------------
  describe "pagination keys" do
  end

  # I put this as "may" because pagination is an optional feature
  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # Concepts of order, as expressed in the naming of pagination links, MUST remain consistent with JSON:API’s pagination rules.
  # --------------------------
  describe "pagination links order" do
  end

  # I put this as "may" because pagination is an optional feature
  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The page query parameter is reserved for pagination. Servers and clients SHOULD use this key for pagination operations.
  # --------------------------
  describe "page query param" do
  end

  # TODO: Figure out what our pagination strategy is from this note:
  # Note: JSON:API is agnostic about the pagination strategy used by a server.
  # Effective pagination strategies include (but are not limited to): page-based, offset-based, and cursor-based.
  # The page query parameter can be used as a basis for any of these strategies.
  # For example, a page-based strategy might use query parameters such as page[number] and page[size], an offset-based strategy might use page[offset] and page[limit], while a cursor-based strategy might use page[cursor].

  # TODO: Figure out what to do about this note about unencoded characters
  # Note: The example query parameters above use unencoded [ and ] characters simply for readability. In practice, these characters must be percent-encoded, per the requirements in RFC 3986.

  # TODO: Figure out what to do about this note about pagination with INDEX requests...
  # Note: This section applies to any endpoint that responds with a resource collection as primary data, regardless of the request type.
end
