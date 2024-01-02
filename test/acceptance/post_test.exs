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
        get(:read)
        index(:read)
        post :confirm_name, route: "/confirm_name"
      end
    end

    actions do
      defaults([:read, :update, :destroy])
      create(:create, primary?: true)

      create :confirm_name do
        argument(:confirm, :string, allow_nil?: false)
        validate(confirm(:name, :confirm))
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string)
    end

    relationships do
      has_many(:posts, Test.Acceptance.PostTest.Post, destination_attribute: :author_id)
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
        get(:read)
        index(:read)

        post(:create,
          relationship_arguments: [:author],
          default_fields: [:name, :email, :hidden, :name_twice]
        )

        post(:accepts_email,
          upsert?: true,
          upsert_identity: :unique_email,
          route: "/upsert_by_email"
        )
      end
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :name, :hidden])

        argument(:author, :map)

        change(manage_relationship(:author, type: :append_and_remove))
      end

      create :accepts_email do
        accept([:name, :email])
      end
    end

    identities do
      identity(:unique_email, [:email], pre_check_with: Test.Acceptance.PostTest.Api)
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, allow_nil?: false)
      attribute(:hidden, :string)

      attribute(:email, :string,
        allow_nil?: true,
        constraints: [
          match: ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
        ]
      )
    end

    relationships do
      belongs_to(:author, Test.Acceptance.PostTest.Author, allow_nil?: true)
    end

    calculations do
      calculate(:name_twice, :string, concat([:name, :name], "-"))
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
      router(Test.Acceptance.PostTest.Router)
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
  describe "invalid_post" do
    test "create without all attributes in accept list" do
      id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 1"
            }
          }
        })

      # response is a Plug.
      assert %{"data" => %{"attributes" => %{"hidden" => nil}}} = response.resp_body
    end
  end

  @tag :attributes
  describe "post" do
    test "create with all attributes in accept list" do
      id = Ecto.UUID.generate()

      Api
      |> post("/posts", %{
        data: %{
          type: "post",
          attributes: %{
            id: id,
            name: "Post 1",
            hidden: "hidden"
          }
        }
      })
      |> assert_attribute_equals("email", nil)
      |> assert_attribute_equals("name_twice", "Post 1-Post 1")
    end
  end

  describe "post with upsert" do
    post =
      Api.create!(
        Ash.Changeset.for_create(Post, :create, %{name: "Post"})
        |> Ash.Changeset.force_change_attribute(:email, "foo@bar.com")
      )

    Api
    |> post("/posts/upsert_by_email", %{
      data: %{
        type: "post",
        attributes: %{
          name: "New Post",
          email: post.email
        }
      }
    })
    |> assert_attribute_equals("name", "New Post")
    |> assert_id_equals(post.id)
  end

  describe "post_email_id_exception" do
    test "create with all attributes in accept list with email" do
      id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 2",
              hidden: "hidden",
              email: "dummy@test.com"
            }
          }
        })

      # response is a Plug.
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "InvalidBody"

      assert error["detail"] ==
               "Expected only defined properties, got key [\"data\", \"attributes\", \"email\"]."
    end
  end

  describe "post_email_id_relationship" do
    setup do
      author =
        Author
        |> Ash.Changeset.new(%{id: Ecto.UUID.generate(), name: "John"})
        |> Api.create!()

      %{author: author}
    end

    test "create with all attributes in accept list without email along with relationship", %{
      author: author
    } do
      id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Post 2",
              hidden: "hidden"
            },
            relationships: %{
              author: %{
                data: %{id: author.id, type: "author"}
              }
            }
          }
        })

      # response is a Plug.
      assert %{"data" => %{"attributes" => %{"hidden" => "hidden"}}} = response.resp_body
    end

    test "create with all attributes in accept list with email along with relationship", %{
      author: author
    } do
      id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 3",
              hidden: "hidden",
              email: "dummy@test.com"
            },
            relationships: %{
              author: %{
                data: %{id: author.id, type: "author"}
              }
            }
          }
        })

      # response is a Plug.
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "InvalidBody"

      assert error["detail"] ==
               "Expected only defined properties, got key [\"data\", \"attributes\", \"email\"]."
    end

    test "arguments are validated properly" do
      Api
      |> post(
        "/authors/confirm_name",
        %{
          data: %{
            type: "author",
            attributes: %{
              name: "foo",
              confirm: "bar"
            }
          }
        },
        status: 400
      )
    end

    test "arguments are threaded through properly" do
      Api
      |> post(
        "/authors/confirm_name",
        %{
          data: %{
            type: "author",
            attributes: %{
              name: "foo",
              confirm: "bar"
            }
          }
        }
      )
    end
  end
end
