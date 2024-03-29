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

        index(:read)
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
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router(Test.Acceptance.IndexPaginationTest.Router)
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

      data = response.resp_body["data"]
      assert length(data) == 5
    end
  end
end
