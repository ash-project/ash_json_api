# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.Links do
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.Links.Domain,
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
          keyset?: true,
          default_limit: 5
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

  defmodule TestPhoenixEndpoint do
    def url do
      "https://test-endpoint.com"
    end
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    :ok
  end

  setup do
    posts =
      for index <- 1..15 do
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo-#{index}"})
        |> Ash.create!()
      end

    [posts: posts]
  end

  describe "link generation" do
    test "generates links when Phoenix Endpoint is present" do
      page_size = 5
      conn = get(Domain, "/posts", phoenix_endpoint: TestPhoenixEndpoint, status: 200)

      {:ok, %Ash.Page.Keyset{} = keyset} =
        Ash.read(Post,
          page: [limit: page_size]
        )

      after_cursor = List.last(keyset.results).__metadata__.keyset

      assert_equal_links(conn, %{
        "first" => "http://www.example.com/posts?page[limit]=#{page_size}",
        "next" =>
          "http://www.example.com/posts?page[after]=#{after_cursor}&page[limit]=#{page_size}",
        "prev" => nil,
        "self" => "http://www.example.com/posts?page[limit]=#{page_size}"
      })
    end
  end
end
