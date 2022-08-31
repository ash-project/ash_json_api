defmodule Test.Acceptance.BelongsToRequiredTest do
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
      has_many(:posts, Test.Acceptance.BelongsToRequiredTest.Post,
        destination_attribute: :author_id
      )
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
        post(:create, relationship_arguments: [{:id, :author}])
      end
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :name, :hidden])
        argument(:author, :uuid)

        change(manage_relationship(:author, type: :replace))
      end
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
      belongs_to(:author, Test.Acceptance.BelongsToRequiredTest.Author, required?: true)
    end
  end

  defmodule Registry do
    use Ash.Registry

    entries do
      entry(Post)
      entry(Author)
    end
  end

  defmodule Api do
    use Ash.Api,
      extensions: [
        AshJsonApi.Api
      ]

    json_api do
      router(Test.Acceptance.BelongsToRequiredTest.Router)
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
    test "create without an author_id in relationship" do
      id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 1"
            },
            relationships: %{
              author: %{
                data: %{}
              }
            }
          }
        })

      # response is a Plug.
      assert response.status == 400

      assert Enum.any?(response.resp_body["errors"], &(&1["code"] == "required"))
    end

    test "create without an author in relationship" do
      id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 1"
            },
            relationships: %{}
          }
        })

      assert response.status == 400
      assert Enum.any?(response.resp_body["errors"], &(&1["code"] == "required"))
    end

    test "create with invalid author id in relationship" do
      id = Ecto.UUID.generate()
      author_id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 2"
            },
            relationships: %{
              author: %{
                data: %{id: author_id, type: "author"}
              }
            }
          }
        })

      # response is a Plug.
      assert response.status == 400
      assert Enum.any?(response.resp_body["errors"], &(&1["code"] == "not_found"))
    end
  end

  @tag :attributes
  describe "post" do
    setup do
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{id: Ecto.UUID.generate(), name: "John"})
        |> Api.create!()

      %{author: author}
    end

    test "create with all attributes in accept list", %{author: author} do
      id = Ecto.UUID.generate()

      Api
      |> post(
        "/posts",
        %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Post 1",
              hidden: "hidden"
            },
            relationships: %{
              author: %{
                data: %{id: author.id, type: "author"}
              }
            }
          }
        },
        status: 201
      )
      |> assert_attribute_equals("email", nil)
    end
  end
end
