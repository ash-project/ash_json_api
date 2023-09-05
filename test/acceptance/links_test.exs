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
      router(Test.Acceptance.Links.Router)
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
      page_size = 5
      conn = get(Api, "/posts", phoenix_endpoint: TestPhoenixEndpoint, status: 200)

      {:ok, %Ash.Page.Keyset{} = keyset} =
        Api.read(Post,
          page: [limit: page_size]
        )

      after_cursor = List.last(keyset.results).__metadata__.keyset

      assert_equal_links(conn, %{
        "first" => "#{TestPhoenixEndpoint.url()}?page[limit]=#{page_size}",
        "next" =>
          "#{TestPhoenixEndpoint.url()}?page[after]=#{after_cursor}&page[limit]=#{page_size}",
        "prev" => nil,
        "self" => "#{TestPhoenixEndpoint.url()}?page[limit]=#{page_size}"
      })
    end
  end
end
