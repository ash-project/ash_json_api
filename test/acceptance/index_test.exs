defmodule Test.Acceptance.IndexTest do
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.IndexTest.Domain,
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
              "foo" => "bar"
            }
          end)
        end
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:content, :string, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router Test.Acceptance.IndexTest.Router
      log_errors?(false)

      routes do
        index(Post, :read, route: "/posts/names", default_fields: [:name])
      end
    end

    resources do
      resource(Post)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  describe "index endpoint" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", content: "bar baz"})
        |> Ash.create!()

      %{post: post}
    end

    test "returns a list of posts", %{post: post} do
      Domain
      |> get("/posts", status: 200)
      |> assert_data_equals([
        %{
          "attributes" => %{
            "name" => "foo",
            "content" => "bar baz"
          },
          "id" => post.id,
          "links" => %{},
          "meta" => %{},
          "relationships" => %{},
          "type" => "post"
        }
      ])
    end

    test "returns custom metadata for the index endpoint" do
      Domain
      |> get("/posts", status: 200)
      |> assert_meta_equals(%{
        "foo" => "bar"
      })
    end

    test "returns a list of posts names only", %{post: post} do
      Domain
      |> get("/posts/names", status: 200)
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
    Domain
    |> get("/posts", status: 200)
    |> assert_data_equals([])
  end
end
