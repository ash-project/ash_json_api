defmodule Test.Acceptance.GetTest do
  use ExUnit.Case, async: true

  defmodule CustomError do
    use Ash.Error.Exception

    use Splode.Error,
      fields: [],
      class: :invalid

    def message(_), do: "ruh roh"

    defimpl AshJsonApi.ToJsonApiError do
      def to_json_api_error(_error) do
        %AshJsonApi.Error{
          id: Ash.UUID.generate(),
          status_code: 409,
          code: "not_available",
          title: "not_available",
          detail: "Not available"
        }
      end
    end
  end

  defmodule Profile do
    use Ash.Resource,
      data_layer: :embedded

    attributes do
      attribute(:bio, :string, public?: true)
    end
  end

  defmodule Post do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      domain: Test.Acceptance.GetTest.Domain,
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

        get :read do
          metadata(fn query, result, request ->
            %{
              "bar" => "baz"
            }
          end)
        end

        get(:by_name, route: "/by_name/:name")
        get(:with_error, route: "/with_error/:id")

        index(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :update, :destroy])

      read :with_error do
        prepare(fn query, _ ->
          Ash.Query.add_error(query, CustomError.exception([]))
        end)
      end

      read :read do
        primary? true
        prepare(build(load: [:name_twice]))
      end

      read :by_name do
        argument(:name, :string, allow_nil?: false)

        filter(name: arg(:name))
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:tag, :string, public?: true)
      attribute(:profile, Profile, public?: true)
      attribute(:hidden, :string)
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
      router(Test.Acceptance.GetTest.Router)
      log_errors?(false)
    end

    resources do
      resource(Post)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  describe "not_found" do
    test "returns a 404 error for a non-existent error" do
      id = Ecto.UUID.generate()

      Domain
      |> get("/posts/#{id}", status: 404)
      |> assert_has_error(%{
        "code" => "not_found",
        "detail" => "No post record found with `id: #{id}`",
        "title" => "Entity Not Found"
      })
    end
  end

  describe "custom errors" do
    test "custom errors are rendered according to `ToJsonApiError`" do
      id = Ecto.UUID.generate()

      Domain
      |> get("/posts/with_error/#{id}", status: 409)
      |> assert_has_error(%{
        "code" => "not_available",
        "detail" => "Not available",
        "title" => "not_available"
      })
    end
  end

  @tag :arguments
  describe "arguments" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Ash.create!()

      %{post: post}
    end

    test "arguments can be used in routes" do
      Domain
      |> get("/posts/by_name/foo", status: 200)
      |> assert_attribute_equals("name", "foo")
    end
  end

  describe "calculations" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Ash.create!()

      %{post: post}
    end

    test "calculation arguments are parsed out of field_inputs", %{post: post} do
      Domain
      |> get(
        "/posts/#{post.id}?fields[post]=name_twice,name_tripled&field_inputs[post][name_twice][separator]=foo&field_inputs[post][name_tripled][separator]=bar",
        status: 200
      )
      |> assert_attribute_equals("name_twice", post.name <> "foo" <> post.name)
      |> assert_attribute_equals(
        "name_tripled",
        post.name <> "bar" <> post.name <> "bar" <> post.name
      )
    end
  end

  @tag :attributes
  describe "attributes" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", tag: "ash", profile: %{bio: "Bio"}})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Ash.create!()

      %{post: post}
    end

    test "string attributes are rendered properly", %{post: post} do
      Domain
      |> get("/posts/#{post.id}", status: 200)
      |> assert_meta_equals(%{
        "bar" => "baz"
      })
      |> assert_attribute_equals("name", post.name)
    end

    test "string attributes accessed with the fields param render properly", %{post: post} do
      Domain
      |> get("/posts/#{post.id}?fields[post]=tag", status: 200)
      |> assert_attribute_equals("tag", post.tag)
    end

    test "calculated fields are rendered properly in a field param", %{post: post} do
      Domain
      |> get("/posts/#{post.id}?fields[post]=name_twice")
      |> assert_attribute_equals("name_twice", post.name <> "-" <> post.name)
    end

    test "calculated fields are rendered properly by default", %{post: post} do
      Domain
      |> get("/posts/#{post.id}")
      |> assert_attribute_equals("name_twice", post.name <> "-" <> post.name)
    end

    test "calculated fields can be sorted on", %{post: post} do
      Domain
      |> get("/posts/#{post.id}?sort=name_twice&fields=name_twice")
      |> assert_attribute_equals("name_twice", post.name <> "-" <> post.name)
    end

    test "calculated fields not loaded are skipped", %{post: post} do
      Domain
      |> get("/posts/#{post.id}")
      |> assert_attribute_missing("name_tripled")
    end

    test "calculated fields unloaded by default are loaded if specified", %{post: post} do
      Domain
      |> get("/posts/#{post.id}?fields[post]=name_tripled")
      |> assert_attribute_equals(
        "name_tripled",
        post.name <> "-" <> post.name <> "-" <> post.name
      )
    end

    @tag :attributes
    test "private attributes are not rendered in the payload", %{post: post} do
      Domain
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_missing("hidden")
    end

    @tag :attributes
    test "primary keys are not rendered in attributes object", %{post: post} do
      Domain
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_missing("id")
    end
  end
end
