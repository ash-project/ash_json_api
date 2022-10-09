defmodule Test.Acceptance.DeleteTest do
  use ExUnit.Case, async: true

  defmodule Profile do
    use Ash.Resource,
      data_layer: :embedded

    attributes do
      attribute(:bio, :string)
    end
  end

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

        delete(:destroy)
        index(:read)
      end
    end

    actions do
      defaults([:read, :create, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:hidden, :string, private?: true)
      attribute(:profile, Profile)
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
      router(Test.Acceptance.DeleteTest.Router)
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

  describe "not_found" do
    test "returns a 404 error for a non-existent error" do
      id = Ecto.UUID.generate()

      Api
      |> delete("/posts/#{id}", status: 404)
      |> assert_has_error(%{
        "code" => "NotFound",
        "detail" => "No post record found with `id: #{id}`",
        "title" => "Entity Not Found"
      })
    end
  end

  describe "found" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", profile: %{bio: "Bio"}})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Api.create!()

      %{post: post}
    end

    test "delete responds with 200", %{post: post} do
      Api
      |> delete("/posts/#{post.id}", status: 200)
    end
  end
end
