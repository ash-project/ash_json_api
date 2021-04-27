defmodule Test.Acceptance.IndexTest do
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

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
    end
  end

  defmodule Api do
    use Ash.Api,
      extensions: [
        AshJsonApi.Api
      ]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Post)
    end
  end

  import AshJsonApi.Test

  describe "index endpoint" do
    setup do
      post =
        Post
        |> Ash.Changeset.new(%{name: "foo"})
        |> Api.create!()

      %{post: post}
    end

    test "returns a list of posts", %{post: post} do
      response =
        Api
        |> get("/posts", status: 200)
        |> assert_data_equals([
          %{
            "attributes" => %{
              "name" => "foo"
            },
            "id" => post.id,
            "links" => %{},
            "meta" => %{},
            "relationships" => %{},
            "type" => "post"
          }
        ])
    end
  end

  test "posts table returns empty list" do
    Api
    |> get("/posts", status: 200)
    |> assert_data_equals([])
  end
end
