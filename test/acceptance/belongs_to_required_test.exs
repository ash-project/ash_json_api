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
        get(:default)
        index(:default)
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
      has_many(:posts, Test.Acceptance.BelongsToRequiredTest.Post, destination_field: :author_id)
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
    end

    actions do
      read(:default)

      create :default do
        accept([:id, :name, :hidden, :author])
      end
    end

    attributes do
      attribute(:id, :uuid, primary_key?: true, allow_nil?: false)
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
      assert %{"errors" => [%{"code" => "required"}]} = response.resp_body
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

      # response is a Plug.
      assert response.status == 400
      assert %{"errors" => [%{"code" => "InvalidBody"}]} = response.resp_body
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
      assert %{"errors" => [%{"code" => "not_found"}]} = response.resp_body
    end
  end

  @tag :attributes
  describe "post" do
    setup do
      author =
        Author
        |> Ash.Changeset.new(%{id: Ecto.UUID.generate(), name: "John"})
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
