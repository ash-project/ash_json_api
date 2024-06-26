defmodule Test.Acceptance.DeleteTest do
  use ExUnit.Case, async: true

  defmodule Profile do
    use Ash.Resource,
      data_layer: :embedded

    attributes do
      attribute(:bio, :string, public?: true)
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.DeleteTest.Domain,
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

        delete :destroy do
          metadata(fn query, result, request ->
            %{
              "baz" => "bar"
            }
          end)
        end

        delete :fake_delete do
          route "/delete_fake/:id"
        end

        index(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create, :update, :destroy])

      action :fake_delete, :struct do
        constraints(instance_of: __MODULE__)
        argument(:id, :uuid)

        run(fn input, _ ->
          Ash.get(__MODULE__, input.arguments.id)
        end)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:profile, Profile, public?: true)
      attribute(:hidden, :string)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router(Test.Acceptance.DeleteTest.Router)
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
      |> delete("/posts/#{id}", status: 404)
      |> assert_has_error(%{
        "code" => "not_found",
        "detail" => "No post record found with `id: #{id}`",
        "title" => "Entity Not Found"
      })
    end
  end

  describe "found" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo", profile: %{bio: "Bio"}})
        |> Ash.Changeset.force_change_attribute(:hidden, "hidden")
        |> Ash.create!()

      %{post: post}
    end

    test "delete responds with 200", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}", status: 200)
      |> assert_meta_equals(%{
        "baz" => "bar"
      })
    end

    test "a generic action returns a 200 as well", %{post: post} do
      Domain
      |> delete("/posts/delete_fake/#{post.id}", status: 200)
    end
  end
end
