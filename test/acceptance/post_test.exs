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

      fields [:id, :name]
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

      fields [:id, :name, :hidden, :email]
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

  import AshJsonApi.Test

  @tag :attributes
  describe "invalid_post" do
    test "create without all attributes in accept list" do
      # dummy response.
      # %{
      #   "errors" => [
      #     %{
      #       "code" => "InvalidBody",
      #       "detail" => "Expected only defined properties, got key [\"data\", \"attributes\", \"email\"].",
      #       "id" => "98f356c4-4864-4382-adcb-629beb8b01f1",
      #       "source" => %{"pointer" => "data/attributes/email"},
      #       "title" => "Invalid Body"
      #     }
      #   ],
      #   "jsonapi" => %{"version" => "1.0"}
      # }

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
    end
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
      assert %{"errors" => _} = response.resp_body
    end
  end

  describe "post_email_id_relationship" do
    test "create with all attributes in accept list without email along with relationship" do
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
              # email: "dummy@test.com"
            },
            relationships:
              %{
                # author: %{
                #   data: %{}
                # }
              }
          }
        })

      # response is a Plug.
      IO.inspect(response.resp_body)
      assert %{"data" => %{"attributes" => %{"hidden" => "hidden"}}} = response.resp_body
    end

    test "create with all attributes in accept list with email along with relationship" do
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
            relationships:
              %{
                # author: %{
                #   data: %{}
                # }
              }
          }
        })

      # response is a Plug.
      IO.inspect(response.resp_body)
      assert %{"errors" => _} = response.resp_body
    end
  end

  describe "post_email_id_exception_relationship" do
    test "create with all attributes in accept list with email along with relationship" do
      id = Ecto.UUID.generate()

      response =
        Api
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 3",
              hidden: "hidden"
              # email: "dummy@test.com"
            },
            relationships:
              %{
                # author: %{
                #   data: %{}
                # }
              }
          }
        })

      # response is a Plug.
      IO.inspect(response.resp_body)
      assert %{"errors" => _} = response.resp_body
    end
  end
end
