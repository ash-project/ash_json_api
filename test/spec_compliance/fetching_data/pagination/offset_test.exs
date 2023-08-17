defmodule AshJsonApiTest.FetchingData.Pagination.Offset do
  use ExUnit.Case

  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength
  defmodule Post do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("post")

      routes do
        base("/posts")
        get(:read)
        index(:read)
      end
    end

    actions do
      defaults([:create, :update, :destroy])

      read :read do
        primary? true

        pagination(
          offset?: true,
          default_limit: 5,
          countable: true
        )
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)

      timestamps(private?: false)
    end
  end

  defmodule Registry do
    use Ash.Registry

    entries do
      entry(Post)
    end
  end

  defmodule Api do
    use Ash.Api,
      extensions: [
        AshJsonApi.Api
      ]

    json_api do
      router(AshJsonApiTest.FetchingData.Pagination.Offset.Router)
    end

    resources do
      registry(Registry)
    end
  end

  defmodule Router do
    use AshJsonApi.Api.Router, registry: Registry, api: Api
  end

  import AshJsonApi.Test

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY choose to limit the number of resources returned in a response to a subset (“page”) of the whole set available.
  # --------------------------
  describe "[Offset] limit" do
    setup do
      # Create 10 posts

      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Api.create!()
        end

      [posts: posts]
    end

    test "uses default limit for action" do
      # Read first 5 posts
      # Prev: 1, Next: 5
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------|--------------------------

      conn = get(Api, "/posts", status: 200)

      assert %{"data" => data} = conn.resp_body

      assert Enum.count(data) == 5
    end

    test "respects limit when set in the query" do
      # Read first 8 posts
      # Prev: 1, Next: 8
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------------|--------------------

      page_size = 8

      conn = get(Api, "/posts?page[limit]=#{page_size}", status: 200)

      assert %{"data" => data} = conn.resp_body

      assert Enum.count(data) == page_size
    end
  end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY provide links to traverse a paginated data set (“pagination links”).
  # --------------------------
  # Pagination links MUST appear in the links object that corresponds to a collection.
  # --------------------------
  #
  # To paginate the primary data, supply pagination links in the top-level links object.
  # To paginate an included collection returned in a compound document, supply pagination links in the corresponding links object.

  describe "[Offset] pagination links location" do
    setup do
      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Api.create!()
        end

      [posts: posts, page_size: 5]
    end

    test "next, prev, first & self links are present" do
    end
  end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The following keys MUST be used for pagination links:
  # first: the first page of data
  # last: the last page of data
  # prev: the previous page of data
  # next: the next page of data
  #
  # Following examples from https://jsonapi.org/profiles/ethanresnick/cursor-pagination/#auto-id-links
  # Keys MUST either be omitted or have a null value to indicate that a particular link is unavailable.
  # --------------------------
  describe "[Offset] pagination keys" do
    setup do
      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Api.create!()
        end

      [posts: posts, page_size: 5]
    end

    test "[Initial] when paginating with no cursors set and there are results, next is set, prev is nil" do
    end

    test "[Before] when there are no more results, prev is nil" do
    end

    test "[Before] when there are results, prev and next are set" do
    end

    test "[After] when there are results, prev & next are set" do
    end

    test "[After] when there are no more results, next is nil" do
    end
  end

  # ** Not sure what this is supposed to do

  # @tag :spec_may
  # # JSON:API 1.0 Specification
  # # --------------------------
  # # Concepts of order, as expressed in the naming of pagination links, MUST remain consistent with JSON:API’s pagination rules.
  # # --------------------------
  # describe "[Offset] pagination links order" do
  # end

  # Maybe duplicate work from [Offset] pagination keys, not sure if we should seperate this test
  # @tag :spec_may
  # # JSON:API 1.0 Specification
  # # --------------------------
  # # The page query parameter is reserved for pagination. Servers and clients SHOULD use this key for pagination operations.
  # # Following examples from https://jsonapi.org/profiles/ethanresnick/cursor-pagination/#auto-id-query-parameters
  # # --------------------------
  # describe "[Offset] page query param" do

  # end

  @tag :spec_may
  # JSON:API 1.0 Specification
  # --------------------------
  # The pagination metadata MAY contain a `total` member containing an integer indicating the total number of items
  # in the list of results that's being paginated
  # --------------------------
  # Using examples from https://jsonapi.org/profiles/ethanresnick/cursor-pagination/#auto-id-collection-sizes
  describe "[Offset] Pagination meta" do
    setup do
      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Api.create!()
        end

      [posts: posts, page_size: 5]
    end

    # The pagination metadata MAY contain a `total` member containing an integer indicating the total number of items
    # in the list of results that's being paginated
    test "collection total is included when specified" do
      page_size = 5

      conn =
        get(
          Api,
          "/posts?sort=-inserted_at&page[size]=#{page_size}&page[count]=true",
          status: 200
        )

      assert %{"meta" => meta} = conn.resp_body

      assert meta == %{"page" => %{"total" => 15}}
    end

    test "collection total is nil when count is false" do
      page_size = 5

      conn =
        get(
          Api,
          "/posts?sort=-inserted_at&page[size]=#{page_size}&page[count]=false",
          status: 200
        )

      assert %{"meta" => meta} = conn.resp_body

      assert meta == %{"page" => %{"total" => nil}}
    end
  end

  # defp encode_page_query(page) do
  #   Plug.Conn.Query.encode(%{page: page})
  # end

  # Figure out what our pagination strategy is from this note:
  # Note: JSON:API is agnostic about the pagination strategy used by a server.
  # Effective pagination strategies include (but are not limited to): page-based, offset-based, and cursor-based.
  # The page query parameter can be used as a basis for any of these strategies.
  # For example, a page-based strategy might use query parameters such as page[number] and page[size], an offset-based strategy might use page[offset] and page[limit], while a cursor-based strategy might use page[cursor].

  # Figure out what to do about this note about unencoded characters
  # Note: The example query parameters above use unencoded [ and ] characters simply for readability. In practice, these characters must be percent-encoded, per the requirements in RFC 3986.

  # Figure out what to do about this note about pagination with INDEX requests...
  # Note: This section applies to any endpoint that responds with a resource collection as primary data, regardless of the request type.
end
