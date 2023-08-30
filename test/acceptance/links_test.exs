defmodule Test.Acceptance.Links do
  use ExUnit.Case, async: true

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
          keyset?: true,
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
      router(AshJsonApiTest.FetchingData.Pagination.Keyset.Router)
    end

    resources do
      registry(Registry)
    end
  end

  defmodule Router do
    use AshJsonApi.Api.Router, registry: Registry, api: Api
  end

  defmodule TestPhoenixEndpoint do
    def url() do
      "https://test-endpoint.com"
    end
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

  describe "link generation" do
    test "generates links when Phoenix Endpoint is present" do
      conn = get(Api, "/posts", phoenix_endpoint: TestPhoenixEndpoint, status: 200)

      assert %{"links" => links} = conn.resp_body

      sorted_links =
        links
        |> Map.to_list()
        |> Enum.sort()

      assert sorted_links == [
               {"first", "#{TestPhoenixEndpoint.url}?page[limit]=5"},
               {"next", nil},
               {"prev", nil},
               {"self", "#{TestPhoenixEndpoint.url}?page[limit]=5"}
             ]
    end
  end
end
