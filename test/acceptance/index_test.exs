defmodule Test.Acceptance.IndexTest do
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.IndexTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("post")
      default_fields [:name, :content]

      routes do
        base("/posts")

        index :read do
          metadata(fn query, results, request ->
            %{
              "foo" => "bar"
            }
          end)
        end

        index :read do
          route "/read2"
          default_fields [:not_present_by_default]
        end
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:content, :string, public?: true)
      attribute(:not_present_by_default, :string, public?: true)
    end

    calculations do
      calculate :name_twice, :string, concat([:name, :name], arg(:separator)) do
        argument(:separator, :string, default: "-")
        public?(true)
      end

      calculate :name_tripled, :string, concat([:name, :name, :name], arg(:separator)) do
        argument(:separator, :string, default: "-")
        public?(true)
      end
    end
  end

  defmodule Domain do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router Test.Acceptance.IndexTest.Router
      log_errors?(false)

      routes do
        base_route "/posts", Post do
          index :read do
            route "/names"
            default_fields [:name]
          end
        end
      end
    end

    resources do
      resource(Post)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  describe "index endpoint" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", content: "bar baz"})
        |> Ash.create!()

      %{post: post}
    end

    test "returns a list of posts", %{post: post} do
      Domain
      |> get("/posts", status: 200)
      |> assert_data_equals([
        %{
          "attributes" => %{
            "name" => "foo",
            "content" => "bar baz"
          },
          "id" => post.id,
          "links" => %{},
          "meta" => %{},
          "relationships" => %{},
          "type" => "post"
        }
      ])
    end

    test "returns a list of posts honoring route-specific default fields", %{post: post} do
      Domain
      |> get("/posts/read2", status: 200)
      |> assert_data_equals([
        %{
          "attributes" => %{
            "not_present_by_default" => nil
          },
          "id" => post.id,
          "links" => %{},
          "meta" => %{},
          "relationships" => %{},
          "type" => "post"
        }
      ])
    end

    test "returns custom metadata for the index endpoint" do
      Domain
      |> get("/posts", status: 200)
      |> assert_meta_equals(%{
        "foo" => "bar"
      })
    end

    test "returns a list of posts names only", %{post: post} do
      Domain
      |> get("/posts/names", status: 200)
      |> assert_data_equals([
        %{
          "attributes" => %{
            "name" => "foo"
          },
          "id" => post.id,
          "links" => %{},
          "meta" => %{},
          "relationships" => %{},
          "type" => "post"
        }
      ])
    end

    test "accepts field_inputs as query params", %{post: post} do
      Domain
      |> get(
        "/posts?field_inputs[post][name_twice][separator]=sep&fields=name,name_twice,name_tripled",
        status: 200
      )
      |> assert_data_equals([
        %{
          "attributes" => %{
            "name" => "foo",
            "name_twice" => "foosepfoo",
            "name_tripled" => "foo-foo-foo"
          },
          "id" => post.id,
          "links" => %{},
          "meta" => %{},
          "relationships" => %{},
          "type" => "post"
        }
      ])
    end
  end

  test "posts table returns empty list" do
    Domain
    |> get("/posts", status: 200)
    |> assert_data_equals([])
  end
end
