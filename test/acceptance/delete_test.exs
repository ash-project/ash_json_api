# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

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

        delete :close do
          route "/:id/close"
        end

        delete :guarded_destroy do
          route "/:id/guarded"
          query_params [:confirm]
        end

        index(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create, :update, :destroy])

      update :close do
        change(set_attribute(:name, "closed"))
      end

      destroy :guarded_destroy do
        require_atomic?(false)
        argument(:confirm, :boolean, allow_nil?: false, default: false)
        argument(:force, :boolean, allow_nil?: false, default: false)

        validate(fn changeset, _ ->
          if Ash.Changeset.get_argument(changeset, :confirm) do
            :ok
          else
            {:error, field: :confirm, message: "confirmation required"}
          end
        end)

        validate(fn changeset, _ ->
          if Ash.Changeset.get_argument(changeset, :force) do
            {:error, field: :force, message: "force was bound"}
          else
            :ok
          end
        end)
      end

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
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
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

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    :ok
  end

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

    test "a delete route can run an update action", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/close", status: 200)

      assert Ash.get!(Post, post.id).name == "closed"
    end

    test "a delete update accepts an empty JSON object", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/close", status: 200, body: %{})

      assert Ash.get!(Post, post.id).name == "closed"
    end

    test "a delete update rejects a nonempty request body", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/close",
        status: 400,
        body: %{data: %{attributes: %{name: "changed"}}}
      )

      assert Ash.get!(Post, post.id).name == post.name
    end
  end

  describe "query_params on a destroy route" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      %{post: post}
    end

    test "a listed query param sets the destroy argument", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/guarded?confirm=true", status: 200)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(Post, post.id)
    end

    test "without the query param the argument takes its default", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/guarded", status: 400)
      |> assert_has_error(%{
        "code" => "invalid_argument",
        "detail" => "confirmation required"
      })

      assert Ash.get!(Post, post.id)
    end

    test "a query param not listed on the route is not bound", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/guarded?confirm=true&force=true", status: 200)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(Post, post.id)
    end

    test "arguments in a request body are not bound", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/guarded?confirm=true",
        status: 200,
        body: %{data: %{attributes: %{force: true}}}
      )

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(Post, post.id)
    end

    test "filter and sort query params are not passed as destroy inputs", %{post: post} do
      Domain
      |> delete("/posts/#{post.id}/guarded?confirm=true&filter[name]=foo&sort=name",
        status: 200,
        body: %{data: %{attributes: %{}}}
      )

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(Post, post.id)
    end
  end
end
