defmodule Test.Acceptance.IndexPaginationTest do
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

        index(:read)
      end
    end

    actions do
      defaults([:create, :update, :destroy])

      read :read do
        primary? true
        pagination(offset?: true, required?: true, countable: true, default_limit: 5)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
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
      router(Test.Acceptance.IndexPaginationTest.Router)
      log_errors?(false)
    end

    resources do
      registry(Registry)
    end
  end

  defmodule Router do
    use AshJsonApi.Api.Router, registry: Registry, api: Api
  end

  import AshJsonApi.Test

  describe "index endpoint with pagination" do
    setup do
      posts =
        Enum.each(1..10, fn i ->
          Post
          |> Ash.Changeset.for_create(:create, %{name: "foo_#{i}"})
          |> Api.create!()
        end)

      %{posts: posts}
    end

    test "returns a list of posts - default limit" do
      response =
        Api
        |> get("/posts", status: 200)

      data = response.resp_body["data"]
      assert length(data) == 5
    end

    test "returns a list of posts - pagination limit" do
      response =
        Api
        |> get("/posts?page[limit]=1", status: 200)

      data = response.resp_body["data"]
      assert length(data) == 1
    end

    test "returns a list of posts - pagination limit + offset" do
      response =
        Api
        |> get("/posts?page[offset]=5&page[limit]=10", status: 200)

      data = response.resp_body["data"]
      assert length(data) == 5
    end
  end
end
