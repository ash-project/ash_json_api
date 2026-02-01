# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

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

    @tag capture_log: true
    test "returns 400 when page parameter is not using bracket notation" do
      # Clients must use page[limit]=10 format, not page={"limit":10} or similar
      # URL-encoded: %7B%22limit%22%3A1%7D = {"limit":1}
      response =
        Domain
        |> get("/posts?page=%7B%22limit%22%3A1%7D", status: 400)

      errors = response.resp_body["errors"]

      assert Enum.any?(errors, fn error ->
               error["code"] == "invalid_pagination" and error["detail"] =~ "bracket notation"
             end)
    end
  end
end
