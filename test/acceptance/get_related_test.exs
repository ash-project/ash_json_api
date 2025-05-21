defmodule Test.Acceptance.GetRelatedTest do
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.GetRelatedTest.Domain,
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

    relationships do
      has_many :comments, Test.Acceptance.GetRelatedTest.Comment do
        public?(true)
      end
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

  defmodule Comment do
    use Ash.Resource,
      domain: Test.Acceptance.GetRelatedTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("comment")

      includes :post
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:content, :string, public?: true)
    end

    relationships do
      belongs_to(:post, Post) do
        public?(true)
      end
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
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)

      routes do
        base_route "/posts", Post do
          index :read
          related :comments, :read, primary?: true
        end
      end
    end

    resources do
      resource(Post)
      resource(Comment)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    :ok
  end

  describe "index endpoint" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "parent", content: "parent"})
        |> Ash.create!()

      comments =
        Enum.map(0..1, fn i ->
          Comment
          |> Ash.Changeset.for_create(:create, %{
            name: "comment#{i}",
            content: "comment",
            post_id: post.id
          })
          |> Ash.create!()
        end)

      %{post: post, comments: comments}
    end

    test "returns a list of posts", %{post: post} do
      Domain
      |> get("/posts/#{post.id}/comments", status: 200)
      |> assert_data_matches([
        %{
          "attributes" => %{
            "name" => "comment" <> _,
            "content" => "comment"
          },
          "type" => "comment"
        },
        %{
          "attributes" => %{
            "name" => "comment" <> _,
            "content" => "comment"
          },
          "type" => "comment"
        }
      ])
    end

    test "additional relationships can be included", %{post: post} do
      includes =
        Domain
        |> get("/posts/#{post.id}/comments?include=post", status: 200)
        |> assert_data_matches([
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          },
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          }
        ])
        |> Map.get(:resp_body)
        |> get_in(["included"])

      assert [
               %{
                 "attributes" => %{"content" => "parent", "name" => "parent"},
                 "type" => "post"
               }
             ] = includes
    end

    test "field_inputs can be supplied on includes", %{post: post} do
      includes =
        Domain
        |> get(
          "/posts/#{post.id}/comments?include=post&fields[post]=name_twice&field_inputs[post][name_twice][separator]=baz",
          status: 200
        )
        |> assert_data_matches([
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          },
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          }
        ])
        |> Map.get(:resp_body)
        |> get_in(["included"])

      assert [
               %{
                 "attributes" => %{"name_twice" => "parentbazparent"},
                 "type" => "post"
               }
             ] = includes
    end
  end
end
