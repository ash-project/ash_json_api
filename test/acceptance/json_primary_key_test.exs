defmodule Test.Acceptance.ResourceTest do
  use ExUnit.Case, async: true

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.ResourceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      primary_key do
        keys([:first_name, :age, :last_name, :utc_now])
      end

      routes do
        base("/authors")
        post(:create)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:first_name, :last_name, :age, :utc_now])
      end
    end

    attributes do
      attribute(:first_name, :string, primary_key?: true, allow_nil?: false, public?: true)
      attribute(:last_name, :string, primary_key?: true, allow_nil?: false, public?: true)
      attribute(:utc_now, :utc_datetime, public?: true)
      attribute(:age, :integer, public?: true)
    end
  end

  defmodule Book do
    use Ash.Resource,
      domain: Test.Acceptance.ResourceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("book")

      primary_key do
        keys([:author_name, :name])
        delimiter(",")
      end

      routes do
        base("/books")
        post(:create)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :name, :author_name])
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, public?: true)
      attribute(:author_name, :string, public?: true)
    end
  end

  defmodule Movie do
    use Ash.Resource,
      domain: Test.Acceptance.ResourceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("movie")

      routes do
        base("/movies")
        post(:create)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :name])
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router(Test.Acceptance.ResourceTest.Router)
      log_errors?(false)
    end

    resources do
      resource(Author)
      resource(Book)
      resource(Movie)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  @tag :section
  describe "json response id created from primary key fields" do
    test "returns correct response id" do
      response =
        Domain
        |> post("/authors", %{
          data: %{
            type: "author",
            attributes: %{
              first_name: "Randall",
              last_name: "Munroe",
              age: 36,
              utc_now: ~U[2020-10-20 14:20:56.699470Z]
            }
          }
        })

      # response is a Plug.
      assert response.resp_body["data"]["id"] == "Randall-36-Munroe-2020-10-20 14:20:56Z"
    end
  end

  @tag :section
  describe "json response id created from non primary key fields" do
    test "returns correct response id" do
      response =
        Domain
        |> post("/books", %{
          data: %{
            type: "book",
            attributes: %{
              id: Ecto.UUID.generate(),
              name: "The Lord of the Rings",
              author_name: "J. R. R. Tolkien"
            }
          }
        })

      # response is a Plug.
      assert response.resp_body["data"]["id"] == "J. R. R. Tolkien,The Lord of the Rings"
    end
  end

  @tag :section
  describe "json primary_key is not defined" do
    test "returns default id" do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/movies", %{
          data: %{
            type: "movie",
            attributes: %{
              id: id,
              name: "The Lord of the Rings"
            }
          }
        })

      # response is a Plug.
      assert response.resp_body["data"]["id"] == id
    end
  end

  @tag :transformer
  describe "module has composite key but does not define json primary key" do
    test "raises requires json primary key error" do
      assert_raise Spark.Error.DslError,
                   ~r/AshJsonApi requires primary key when a resource has a composite key/,
                   fn ->
                     defmodule BadResource do
                       use Ash.Resource,
                         domain: nil,
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
                           post(:create)
                         end
                       end

                       actions do
                         create :create do
                           accept([:first_name, :last_name])
                         end
                       end

                       attributes do
                         attribute(:first_name, :string, primary_key?: true, allow_nil?: false)
                         attribute(:last_name, :string, primary_key?: true, allow_nil?: false)
                       end
                     end
                   end
    end
  end

  @tag :transformer
  describe "json primary contains keys which are not the resource's attribute" do
    test "raises invalid primary keys error" do
      assert_raise Spark.Error.DslError,
                   ~r/AshJsonApi primary key must be from the resource's attributes/,
                   fn ->
                     defmodule BadResource do
                       use Ash.Resource,
                         domain: nil,
                         data_layer: Ash.DataLayer.Ets,
                         extensions: [
                           AshJsonApi.Resource
                         ]

                       ets do
                         private?(true)
                       end

                       json_api do
                         type("author")

                         primary_key do
                           keys([:these, :fields, :do, :not, :exist])
                         end

                         routes do
                           base("/authors")
                           post(:create)
                         end
                       end

                       actions do
                         create :create do
                           accept([:first_name, :last_name])
                         end
                       end

                       attributes do
                         attribute(:first_name, :string, primary_key?: true, allow_nil?: false)
                         attribute(:last_name, :string, primary_key?: true, allow_nil?: false)
                       end
                     end
                   end
    end
  end
end
