defmodule Test.Acceptance.PostTest do
  use ExUnit.Case, async: true

  defmodule Author do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      routes do
        base("/authors")
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
      attribute(:id, :uuid, primary_key?: true)
      attribute(:name, :string)
    end

    relationships do
      has_many(:posts, Test.Acceptance.PostTest.Post, destination_field: :author_id)
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
        get(:default)
        index(:default)
        post(:default)
      end

      fields [:name]
    end

    actions do
      read(:default)

      create :default do
        accept([:id, :name, :hidden])
      end
    end

    attributes do
      attribute(:id, :uuid, primary_key?: true)
      attribute(:name, :string)
      attribute(:hidden, :string)

      attribute(:email, :string,
        allow_nil?: true,
        constraints: [
          match: ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
        ]
      )
    end

    relationships do
      belongs_to(:author, Test.Acceptance.PostTest.Author)
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
      resource(Author)
    end
  end

  describe "invalid_post" do
    test "create without all attributes in accept list" do
      post =
        Post
        |> Ash.Changeset.new(%{name: "Invalid Post", hidden: "hidden"})
        |> Api.create!()

      assert is_nil(post.id) == true
      assert is_nil(post.author) == false
    end
  end

  describe "post" do
    test "create with all attributes in accept list" do
      id = Ecto.UUID.generate()

      post =
        Post
        |> Ash.Changeset.new(%{name: "Valid Post", hidden: "hidden", id: id})
        |> Api.create!()

      assert post.name == "Valid Post"
      assert post.id == id
      assert post.hidden == "hidden"
      assert is_nil(post.email)

      assert is_nil(post.author) == false
    end
  end

  describe "post_email_id_exception" do
    test "create with all attributes in accept list with email" do
      assert_raise Ash.Error.Invalid, fn ->
        _ =
          Post
          |> Ash.Changeset.new(%{
            name: "Invalid Post 2",
            hidden: "hidden",
            id: Ecto.UUID.generate(),
            email: "DUMMY@TEST.COM"
          })
          |> Api.create!()
      end
    end
  end

  describe "post_email_id_exception_relationship" do
    test "create with all attributes in accept list with email along with relationship" do
      assert_raise Ash.Error.Invalid, fn ->
        _ =
          Post
          |> Ash.Changeset.new(%{
            name: "Invalid Post 3",
            hidden: "hidden",
            id: Ecto.UUID.generate(),
            email: "DUMMY@TEST.COM"
          })
          |> Api.create!()
      end
    end
  end
end
