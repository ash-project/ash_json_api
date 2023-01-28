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
        get :read
        index :read
      end
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string)
    end

    relationships do
      has_many(:posts, Test.Acceptance.PatchTest.Post, destination_attribute: :author_id)
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
        get :read
        index :read
        post :create
        patch :update, relationship_arguments: [:author]

        patch :update do
          read_action(:by_name)
          route("/by_name/:name")
        end
      end
    end

    actions do
      defaults([:read, :destroy])

      create :create do
        primary? true
        accept([:id, :name])
      end

      update :update do
        primary? true
        accept([:id, :email])
        argument(:author, :map)

        change(manage_relationship(:author, type: :append_and_remove))
      end

      read :by_name do
        argument :name, :string do
          allow_nil?(false)
        end

        filter(expr(name == ^arg(:name)))
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
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

  defmodule Registry do
    use Ash.Registry

    entries do
      entry(Author)
      entry(Post)
    end
  end

  defmodule Api do
    use Ash.Api,
      extensions: [
        AshJsonApi.Api
      ]

    json_api do
      router(Test.Acceptance.PatchTest.Router)
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

  @tag :attributes
  describe "attributes" do
    setup do
      id = Ecto.UUID.generate()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "Valid Post", hidden: "hidden", id: id})
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

  describe "routes" do
    setup do
      id = Ecto.UUID.generate()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "Valid Post", hidden: "hidden", id: id})
        |> Api.create!()

      %{post: post}
    end

    test "allows using a different read action", %{post: post} do
      response =
        Api
        |> patch("/posts/by_name/#{post.name}", %{
          data: %{
            type: "post",
            attributes: %{
              email: "dummy@test.com"
            }
          }
        })

      assert %{"data" => %{"attributes" => %{"email" => email}}} = response.resp_body
      assert email == "dummy@test.com"
    end
  end

  describe "patch_email_id_exception_relationship" do
    setup do
      id = Ecto.UUID.generate()

      author =
        Author
        |> Ash.Changeset.for_create(:create, %{id: Ecto.UUID.generate(), name: "John"})
        |> Api.create!()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "Valid Post", hidden: "hidden", id: id})
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
