defmodule Test.Acceptance.PatchTest do
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
        get :default
        index :default
      end
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
      has_many(:posts, Test.Acceptance.PatchTest.Post, destination_field: :author_id)
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
        get :default
        index :default
        post :default
        patch :default
      end
    end

    actions do
      read(:default)

      create :default do
        accept([:id, :name, :hidden])
      end

      update :default do
        accept([:id, :email, :author])
      end
    end

    attributes do
      attribute(:id, :uuid, primary_key?: true)
      attribute(:name, :string)
      attribute(:hidden, :string, private?: true)

      attribute(:email, :string,
        allow_nil?: true,
        constraints: [
          match: ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
        ]
      )
    end

    relationships do
      belongs_to(:author, Test.Acceptance.PatchTest.Author)
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

  describe "patch" do
    test "Update post with email id" do
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

  import AshJsonApi.Test

  @tag :attributes
  describe "attributes" do
    setup do
      id = Ecto.UUID.generate()

      post =
        Post
        |> Ash.Changeset.new(%{name: "Valid Post", hidden: "hidden", id: id})
        |> Api.create!()

      %{post: post}
    end

    test "string attributes are rendered properly", %{post: post} do
      Api
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_equals("name", post.name)
    end

    test "patch working properly", %{post: post} do
      Api
      |> patch("/posts/#{post.id}", %{data: %{attributes: %{email: "dummy@test.com"}}})
      |> assert_attribute_equals("email", "dummy@test.com")
    end

    @tag :attributes
    test "private attributes are not rendered in the payload", %{post: post} do
      Api
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_missing("hidden")
    end
  end

  describe "patch_email_id_exception_relationship" do
    setup do
      id = Ecto.UUID.generate()

      author =
        Author
        |> Ash.Changeset.new(%{id: Ecto.UUID.generate(), name: "John"})
        |> Api.create!()

      post =
        Post
        |> Ash.Changeset.new(%{name: "Valid Post", hidden: "hidden", id: id})
        |> Api.create!()

      %{post: post, author: author}
    end

    test "Update attributes in accept list with email along with relationship", %{
      post: post,
      author: author
    } do
      response =
        Api
        |> patch("/posts/#{post.id}", %{
          data: %{
            type: "post",
            attributes: %{
              email: "dummy@test.com"
            },
            relationships: %{
              author: %{
                data: %{type: "author", id: author.id}
              }
            }
          }
        })

      assert %{"data" => %{"attributes" => %{"email" => email}}} = response.resp_body
      assert email == "dummy@test.com"
    end

    test "Update attributes in accept list without email along with relationship", %{
      post: post,
      author: author
    } do
      response =
        Api
        |> patch("/posts/#{post.id}", %{
          data: %{
            type: "post",
            attributes: %{},
            relationships: %{
              author: %{
                data: %{type: "author", id: author.id}
              }
            }
          }
        })

      assert %{"data" => %{"attributes" => %{"email" => email}}} = response.resp_body
      assert is_nil(email) == true
    end

    test "Update attributes in accept list without author_id and email_id along with relationship",
         %{post: post} do
      response =
        Api
        |> patch("/posts/#{post.id}", %{
          data: %{
            type: "post",
            attributes: %{},
            relationships: %{}
          }
        })

      assert %{"data" => %{"attributes" => %{"email" => email}}} = response.resp_body
      assert is_nil(email) == true
    end

    test "Update attributes in accept list with email and hidden along with relationship", %{
      post: post,
      author: author
    } do
      response =
        Api
        |> patch("/posts/#{post.id}", %{
          data: %{
            type: "post",
            attributes: %{
              email: "dummy@test.com",
              hidden: "show"
            },
            relationships: %{
              author: %{
                data: %{type: "author", id: author.id}
              }
            }
          }
        })

      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "InvalidBody"

      assert error["detail"] ==
               "Expected only defined properties, got key [\"data\", \"attributes\", \"hidden\"]."
    end
  end
end
