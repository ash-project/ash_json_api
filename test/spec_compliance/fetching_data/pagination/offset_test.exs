defmodule AshJsonApiTest.FetchingData.Pagination.Offset do
  use ExUnit.Case

  @moduletag :json_api_spec_1_0

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength
  defmodule Post do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.Pagination.Offset.Domain,
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
      default_accept(:*)
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
      attribute(:name, :string, public?: true)

      timestamps(public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    resources do
      resource(Post)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    :ok
  end

  # JSON:API 1.0 Specification
  # --------------------------
  # A server MAY choose to limit the number of resources returned in a response to a subset (“page”) of the whole set available.
  # --------------------------
  describe "[Offset] limit" do
    @describetag :spec_may
    setup do
      # Create 10 posts

      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Ash.create!()
        end

      [posts: posts]
    end

    test "uses default limit for action" do
      # Read first 5 posts
      # Prev: 1, Next: 5
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------|--------------------------

      conn = get(Domain, "/posts", status: 200)

      assert %{"data" => data} = conn.resp_body

      assert Enum.count(data) == 5
    end

    test "respects limit when set in the query" do
      # Read first 8 posts
      # Prev: 1, Next: 8
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------------|--------------------

      page_size = 8

      conn = get(Domain, "/posts?page[limit]=#{page_size}", status: 200)

      assert %{"data" => data} = conn.resp_body

      assert Enum.count(data) == page_size
    end
  end

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
    @describetag :spec_may
    setup do
      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Ash.create!()
        end

      [posts: posts, page_size: 5]
    end

    test "next, prev, first & self links are present" do
      # Read first 10 posts
      # Prev: 1, Next: 10
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------|--------------------------

      page_size = 5

      {:ok, %Ash.Page.Offset{} = offset} =
        Ash.read(Ash.Query.sort(Post, inserted_at: :desc), page: [limit: page_size])

      conn = get(Domain, "/posts?sort=-inserted_at", status: 200)

      next_offset = offset.limit

      assert_equal_links(conn, %{
        "first" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "self" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "next" =>
          "http://www.example.com/posts?page[offset]=#{next_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "prev" => nil
      })
    end
  end

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
    @describetag :spec_may
    setup do
      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Ash.create!()
        end

      [posts: posts, page_size: 5]
    end

    test "[Initial] when paginating with no offset params and there are results, next is set, prev is nil" do
      # Read first 5 posts
      # Prev: 1, Next: 5
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------|--------------------------

      page_size = 5

      {:ok, %Ash.Page.Offset{} = offset} =
        Ash.read(Ash.Query.sort(Post, inserted_at: :desc), page: [limit: page_size])

      conn = get(Domain, "/posts?sort=-inserted_at&page[size]=#{page_size}", status: 200)

      next_offset = offset.limit

      assert_equal_links(conn, %{
        "first" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "self" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "next" =>
          "http://www.example.com/posts?page[offset]=#{next_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "prev" => nil
      })
    end

    test "when there are no more results in the prev direction, prev is nil" do
      # Read first 5 posts
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------|--------------------------

      page_size = 5

      {:ok, %Ash.Page.Offset{} = offset} =
        Ash.read(Ash.Query.sort(Post, inserted_at: :desc), page: [limit: page_size, offset: 0])

      conn = get(Domain, "/posts?sort=-inserted_at&page[offset]=0", status: 200)

      next_offset = offset.limit

      assert_equal_links(conn, %{
        "first" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "self" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "next" =>
          "http://www.example.com/posts?page[offset]=#{next_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "prev" => nil
      })
    end

    test "when there are results in both directions, prev and next are set" do
      # Read first 5 posts at offset 10
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # ----------------------|-----------|

      page_size = 5
      initial_offset = page_size * 2

      {:ok, %Ash.Page.Offset{} = offset} =
        Ash.read(Ash.Query.sort(Post, inserted_at: :desc),
          page: [limit: page_size, offset: initial_offset]
        )

      conn = get(Domain, "/posts?sort=-inserted_at&page[offset]=#{initial_offset}", status: 200)

      next_offset = offset.offset + offset.limit
      prev_offset = offset.offset - offset.limit

      assert_equal_links(conn, %{
        "first" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "self" =>
          "http://www.example.com/posts?page[offset]=#{initial_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "next" =>
          "http://www.example.com/posts?page[offset]=#{next_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "prev" =>
          "http://www.example.com/posts?page[offset]=#{prev_offset}&page[limit]=#{page_size}&sort=-inserted_at"
      })
    end

    test "when there are no more results in next direction and count is true, next is nil" do
      # Read first 5 posts at offset 5
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # ----------------------|-----------|

      page_size = 5
      initial_offset = page_size * 2

      {:ok, %Ash.Page.Offset{} = offset} =
        Ash.read(Ash.Query.sort(Post, inserted_at: :desc),
          page: [limit: page_size, offset: initial_offset, count: true]
        )

      conn =
        get(Domain, "/posts?sort=-inserted_at&page[offset]=#{initial_offset}&page[count]=true",
          status: 200
        )

      prev_offset = offset.offset - offset.limit

      assert_equal_links(conn, %{
        "first" =>
          "http://www.example.com/posts?page[count]=true&page[limit]=#{page_size}&sort=-inserted_at",
        "self" =>
          "http://www.example.com/posts?page[count]=true&page[offset]=#{initial_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "next" => nil,
        "last" =>
          "http://www.example.com/posts?page[count]=true&page[offset]=#{initial_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "prev" =>
          "http://www.example.com/posts?page[count]=true&page[offset]=#{prev_offset}&page[limit]=#{page_size}&sort=-inserted_at"
      })
    end

    test "when there are no more results in next direction and count is false, next has an offset" do
      # Read first 5 posts at offset 5
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # ----------------------|-----------|

      page_size = 5
      initial_offset = page_size * 2

      {:ok, %Ash.Page.Offset{} = offset} =
        Ash.read(Ash.Query.sort(Post, inserted_at: :desc),
          page: [limit: page_size, offset: initial_offset]
        )

      conn =
        get(Domain, "/posts?sort=-inserted_at&page[offset]=#{initial_offset}", status: 200)

      next_offset = offset.offset + offset.limit
      prev_offset = offset.offset - offset.limit

      assert_equal_links(conn, %{
        "first" => "http://www.example.com/posts?page[limit]=#{page_size}&sort=-inserted_at",
        "self" =>
          "http://www.example.com/posts?page[offset]=#{initial_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "next" =>
          "http://www.example.com/posts?page[offset]=#{next_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "prev" =>
          "http://www.example.com/posts?page[offset]=#{prev_offset}&page[limit]=#{page_size}&sort=-inserted_at"
      })
    end

    test "when count is true last link is present" do
      # Read first 5 posts
      # 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
      # |-------|--------------------------

      page_size = 5

      {:ok, %Ash.Page.Offset{} = offset} =
        Ash.read(Ash.Query.sort(Post, inserted_at: :desc),
          page: [limit: page_size, offset: page_size, count: true]
        )

      conn =
        get(Domain, "/posts?sort=-inserted_at&page[offset]=#{page_size}&page[count]=true",
          status: 200
        )

      next_offset = offset.offset + offset.limit
      last_offset = offset.count - offset.limit

      assert_equal_links(conn, %{
        "first" =>
          "http://www.example.com/posts?page[count]=true&page[limit]=#{page_size}&sort=-inserted_at",
        "self" =>
          "http://www.example.com/posts?page[count]=true&page[offset]=#{page_size}&page[limit]=#{page_size}&sort=-inserted_at",
        "next" =>
          "http://www.example.com/posts?page[count]=true&page[offset]=#{next_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "last" =>
          "http://www.example.com/posts?page[count]=true&page[offset]=#{last_offset}&page[limit]=#{page_size}&sort=-inserted_at",
        "prev" =>
          "http://www.example.com/posts?page[count]=true&page[limit]=#{page_size}&sort=-inserted_at"
      })
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

  # JSON:API 1.0 Specification
  # --------------------------
  # The pagination metadata MAY contain a `total` member containing an integer indicating the total number of items
  # in the list of results that's being paginated
  # --------------------------
  # Using examples from https://jsonapi.org/profiles/ethanresnick/cursor-pagination/#auto-id-collection-sizes
  describe "[Offset] Pagination meta" do
    @describetag :spec_may
    setup do
      posts =
        for index <- 1..15 do
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
          |> Ash.create!()
        end

      [posts: posts, page_size: 5]
    end

    # The pagination metadata MAY contain a `total` member containing an integer indicating the total number of items
    # in the list of results that's being paginated
    test "collection total is included when count is true" do
      page_size = 5

      conn =
        get(
          Domain,
          "/posts?sort=-inserted_at&page[size]=#{page_size}&page[count]=true",
          status: 200
        )

      assert %{"meta" => meta} = conn.resp_body

      assert meta == %{"page" => %{"total" => 15}}
    end

    test "collection total is not present when count is false" do
      page_size = 5

      conn =
        get(
          Domain,
          "/posts?sort=-inserted_at&page[size]=#{page_size}&page[count]=false",
          status: 200
        )

      assert %{"meta" => meta} = conn.resp_body

      refute Map.has_key?(meta["page"], "total")
    end
  end

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
