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

        get(:default)
        index(:default)
      end

      fields [:name]
    end

    actions do
      read(:default)

      create(:default)
    end

    attributes do
      attribute(:id, :uuid, primary_key?: true, default: &Ecto.UUID.generate/0)
      attribute(:name, :string)
      attribute(:hidden, :string)
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

  @tag :attributes
  describe "attributes" do
    setup do
      post =
        Post
        |> Ash.Changeset.new(%{name: "foo", hidden: "hidden"})
        |> Api.create!()

      %{post: post}
    end

    test "string attributes are rendered properly", %{post: post} do
      Api
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_equals("name", post.name)
    end

    @tag :fields
    test "attributes not declared in `fields` are not rendered in the payload", %{post: post} do
      Api
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_missing("hidden")
    end
  end
end
