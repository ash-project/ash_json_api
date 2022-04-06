defmodule Test.Acceptance.GetTest do
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
        get(:by_name, route: "/by_name/:name")

        index(:read)
      end
    end

    actions do
      read(:read, primary?: true)

      read :by_name do
        argument(:name, :string, allow_nil?: false)

        filter(name: arg(:name))
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:hidden, :string, private?: true)
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
      log_errors?(false)
    end

    resources do
      registry(Registry)
    end
  end

  import AshJsonApi.Test

  describe "not_found" do
    test "returns a 404 error for a non-existent error" do
      id = Ecto.UUID.generate()

      Api
      |> get("/posts/#{id}", status: 404)
      |> assert_has_error(%{
        "code" => "NotFound",
        "detail" => "No post record found with `id: #{id}`",
        "title" => "Entity Not Found"
      })
    end
  end

  @tag :arguments
  describe "arguments" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Api.create!()

      %{post: post}
    end

    test "arguments can be used in routes" do
      Api
      |> get("/posts/by_name/foo", status: 200)
      |> assert_attribute_equals("name", "foo")
    end
  end

  @tag :attributes
  describe "attributes" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Api.create!()

      %{post: post}
    end

    test "string attributes are rendered properly", %{post: post} do
      Api
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_equals("name", post.name)
    end

    @tag :attributes
    test "private attributes are not rendered in the payload", %{post: post} do
      Api
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_missing("hidden")
    end
  end
end
