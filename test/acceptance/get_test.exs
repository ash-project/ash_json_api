defmodule Test.Acceptance.GetTest do
  use ExUnit.Case, async: true
  import AshJsonApi.Test

  defmodule Post do
    use Ash.Resource, name: "posts", type: "post"
    use AshJsonApi.JsonApiResource
    use Ash.DataLayer.Ets, private?: true

    json_api do
      routes do
        get(:default)
        index(:default)
      end

      fields [:name]
    end

    actions do
      defaults([:read, :create],
        rules: [allow(:static, result: true)]
      )
    end

    attributes do
      attribute(:name, :string)
      attribute(:hidden, :string)
    end
  end

  defmodule Api do
    use Ash.Api
    use AshJsonApi.Api

    resources([Post])
  end

  describe "not_found" do
    test "returns a 404 error for a non-existent error" do
      id = Ecto.UUID.generate()

      Api
      |> get("/posts/#{id}", status: 404)
      |> assert_has_error(%{
        "code" => "NotFound",
        "detail" => "No record of post with id: #{id}",
        "title" => "Entity Not Found"
      })
    end
  end

  @tag :attributes
  describe "attributes" do
    setup do
      {:ok, post} = Api.create(Post, %{attributes: %{name: "foo", hidden: "hidden"}})

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
