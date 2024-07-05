defmodule Test.Acceptance.PatchTest do
  use ExUnit.Case, async: true

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.PatchTest.Domain,
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

        patch :delete_posts, route: "/:id/posts/delete"
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])

      update :delete_posts do
        accept([])
        require_atomic?(false)

        argument :post_ids, {:array, :uuid} do
          allow_nil?(false)
        end

        change(manage_relationship(:post_ids, :posts, type: :remove))
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true, public?: true)
      attribute(:name, :string, public?: true)
    end

    relationships do
      has_many(:posts, Test.Acceptance.PatchTest.Post,
        destination_attribute: :author_id,
        public?: true
      )
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.PatchTest.Domain,
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

        patch :update do
          relationship_arguments [:author]

          metadata(fn query, result, request ->
            %{"bar" => "bar"}
          end)
        end

        patch :update do
          read_action(:by_name)
          route("/by_name/:name")

          metadata(fn query, result, request ->
            %{"foo" => "foo"}
          end)
        end

        patch :fake_update do
          route "/fake_update/:id"
        end

        related :author, :read
        patch_relationship :author
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :destroy])

      create :create do
        primary? true
        accept([:id, :name])
      end

      update :update do
        primary? true
        accept([:id, :email])
        argument(:author, :map)
        require_atomic?(false)

        change(manage_relationship(:author, type: :append_and_remove))
      end

      action :fake_update, :struct do
        constraints(instance_of: __MODULE__)
        argument(:id, :uuid, allow_nil?: false)

        run(fn %{arguments: %{id: id}}, _ ->
          updating = Ash.get!(__MODULE__, id)
          {:ok, %{updating | name: updating.name <> "_fake"}}
        end)
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
      attribute(:name, :string, public?: true)

      attribute(:email, :string,
        public?: true,
        allow_nil?: true,
        constraints: [
          match: ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
        ]
      )

      attribute(:hidden, :string)
    end

    relationships do
      belongs_to(:author, Test.Acceptance.PatchTest.Author, public?: true)
    end

    calculations do
      calculate :name_twice, :string, concat([:name, :name], arg(:separator)) do
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
      router(Test.Acceptance.PatchTest.Router)
      log_errors?(false)
    end

    resources do
      resource(Author)
      resource(Post)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  @tag :attributes
  describe "attributes" do
    setup do
      id = Ecto.UUID.generate()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "Valid Post", id: id})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Ash.create!()

      %{post: post}
    end

    test "string attributes are rendered properly", %{post: post} do
      Domain
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_equals("name", post.name)
    end

    test "patch working properly", %{post: post} do
      Domain
      |> patch(
        "/posts/#{post.id}?field_inputs[post][name_twice][separator]=baz&fields[post]=email,name_twice",
        %{
          data: %{attributes: %{email: "dummy@test.com"}}
        }
      )
      |> assert_meta_equals(%{"bar" => "bar"})
      |> assert_attribute_equals("email", "dummy@test.com")
      |> assert_attribute_equals("name_twice", "Valid PostbazValid Post")
    end

    test "patch works with generic actions", %{post: post} do
      Domain
      |> patch(
        "/posts/fake_update/#{post.id}",
        %{
          data: %{attributes: %{}}
        },
        status: 200
      )
      |> assert_data_equals(%{
        "attributes" => %{"author_id" => nil, "email" => nil, "name" => "Valid Post_fake"},
        "id" => post.id,
        "links" => %{},
        "meta" => %{},
        "relationships" => %{"author" => %{"links" => %{}, "meta" => %{}}},
        "type" => "post"
      })
    end

    @tag :attributes
    test "private attributes are not rendered in the payload", %{post: post} do
      Domain
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_missing("hidden")
    end
  end

  describe "routes" do
    setup do
      id = Ecto.UUID.generate()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "Valid Post", id: id})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Ash.create!()

      %{post: post}
    end

    test "allows using a different read action", %{post: post} do
      response =
        Domain
        |> patch("/posts/by_name/#{post.name}", %{
          data: %{
            type: "post",
            attributes: %{
              email: "dummy@test.com"
            }
          }
        })
        |> assert_meta_equals(%{"foo" => "foo"})

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
        |> Ash.create!()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "Valid Post", id: id})
        |> Ash.Changeset.force_change_attribute(:author_id, author.id)
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Ash.create!()

      %{post: post, author: author}
    end

    test "Update attributes in accept list with email", %{
      post: post
    } do
      response =
        Domain
        |> patch("/posts/#{post.id}", %{
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

    test "Update attributes in accept list without email", %{
      post: post
    } do
      response =
        Domain
        |> patch("/posts/#{post.id}", %{
          data: %{
            type: "post",
            attributes: %{}
          }
        })

      assert %{"data" => %{"attributes" => %{"email" => email}}} = response.resp_body
      assert is_nil(email) == true
    end

    test "Update attributes in accept list without author_id and email_id along with relationship",
         %{post: post} do
      response =
        Domain
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
        Domain
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
      assert error["code"] == "invalid_body"
      assert error["source"] == %{"pointer" => "/data/attributes/hidden"}

      assert error["detail"] ==
               "Expected only defined properties, got key [\"data\", \"attributes\", \"hidden\"]."
    end

    test "patch to relationship works", %{
      post: post
    } do
      Domain
      |> patch("/posts/#{post.id}/relationships/author", %{data: []})

      related =
        Domain
        |> get("/posts/#{post.id}/author")
        |> Map.get(:resp_body)
        |> Map.get("data")

      refute related
    end
  end

  describe "patch_removing_posts" do
    setup do
      id = Ecto.UUID.generate()

      author =
        Author
        |> Ash.Changeset.for_create(:create, %{id: Ecto.UUID.generate(), name: "John"})
        |> Ash.create!()

      posts =
        Enum.map(1..2, fn _ ->
          Post
          |> Ash.Changeset.for_create(:create, %{name: "Valid Post", id: id})
          |> Ash.Changeset.force_change_attribute(:author_id, author.id)
          |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
          |> Ash.create!()
        end)

      %{posts: posts, author: author}
    end

    test "patch to remove relationship works", %{author: author, posts: posts} do
      assert %{status: 200} =
               Domain
               |> patch("/authors/#{author.id}/posts/delete", %{
                 data: %{attributes: %{post_ids: Enum.map(posts, & &1.id)}}
               })

      related =
        Domain
        |> get("/authors/#{author.id}/posts")
        |> Map.get(:resp_body)
        |> Map.get("data")

      refute related
    end
  end
end
