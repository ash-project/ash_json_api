defmodule Test.Acceptance.PatchTest do
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
        get :default
        index :default
        post :default
        patch :default
      end

      fields [:name]
    end

    actions do
      read :default

      create :default do
        accept [:id, :name, :hidden]
      end

      update :default do
        accept [:email]
      end
    end

    attributes do
      attribute(:id, :uuid, primary_key?: true)
      attribute(:name, :string)
      attribute(:hidden, :string)
      attribute :email, :string, allow_nil?: true, constraints: [
        match: ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
      ]
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

  describe "patch" do
    test "patch post with email id" do
      id = Ecto.UUID.generate()

      post =
        Post
        |> Ash.Changeset.new(%{name: "Valid Post", hidden: "hidden", id: id})
        |> Api.create!()

      assert post.name == "Valid Post"
      assert post.id == id
      assert post.hidden == "hidden"
      assert is_nil(post.email)

      # this is still incomplete.

    end
  end

end
