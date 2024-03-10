defmodule AshJsonApiTest.FetchingData.Pagination.Links do
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
          default_limit: 5
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
      prefix("/api")
      router(AshJsonApiTest.FetchingData.Pagination.Links.Router)
    end

    resources do
      registry(Registry)
    end
  end

  defmodule Router do
    use AshJsonApi.Api.Router, registry: Registry, api: Api
  end

  import AshJsonApi.Test

  setup do
    posts =
      for index <- 1..15 do
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
        |> Api.create!()
      end

    [posts: posts]
  end

  test "json api prefix should be included in links" do
    page_size = 5

    {:ok, %Ash.Page.Offset{} = offset} =
      Api.read(Ash.Query.sort(Post, inserted_at: :desc), page: [limit: page_size])

    conn = get(Api, "/posts?sort=-inserted_at&page[size]=#{page_size}", status: 200)

    next_offset = offset.limit

    assert_equal_links(conn, %{
      "first" => "http://www.example.com/api/posts?page[limit]=#{page_size}&sort=-inserted_at",
      "self" => "http://www.example.com/api/posts?page[limit]=#{page_size}&sort=-inserted_at",
      "next" =>
        "http://www.example.com/api/posts?page[offset]=#{next_offset}&page[limit]=#{page_size}&sort=-inserted_at",
      "prev" => nil
    })
  end
end
