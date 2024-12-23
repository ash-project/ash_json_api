defmodule Test.Acceptance.IndexPaginationTest do
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.IndexPaginationTest.Domain,
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

        index :read do
          metadata(fn query, results, request ->
            %{
              "baz" => "baz"
            }
          end)
        end
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :update, :destroy])

      read :read do
        primary? true
        pagination(offset?: true, required?: true, countable: true, default_limit: 5)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)
    end

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

  describe "index endpoint with pagination" do
    setup do
      posts =
        Enum.each(1..10, fn i ->
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo_#{i}"})
          |> Ash.create!()
        end)

      %{posts: posts}
    end

    test "returns a list of posts - default limit" do
      response =
        Domain
        |> get("/posts", status: 200)

      data = response.resp_body["data"]
      assert length(data) == 5
    end

    test "returns a list of posts - pagination limit" do
      response =
        Domain
        |> get("/posts?page[limit]=1", status: 200)

      data = response.resp_body["data"]
      assert length(data) == 1
    end

    test "returns a list of posts - pagination limit + offset" do
      response =
        Domain
        |> get("/posts?page[offset]=5&page[limit]=10", status: 200)
        |> assert_meta_equals(%{"baz" => "baz", "page" => %{}})

      data = response.resp_body["data"]
      assert length(data) == 5
    end
  end
end
