# SPDX-FileCopyrightText: 2026 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.RelatedSourceActionTest do
  use ExUnit.Case, async: true

  defmodule Comment do
    use Ash.Resource,
      domain: Test.Acceptance.RelatedSourceActionTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("comment")
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      belongs_to(:post, Test.Acceptance.RelatedSourceActionTest.Post) do
        public?(true)
      end
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.RelatedSourceActionTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("post")

      routes do
        base("/posts")

        related :comments, :read_published, primary?: true
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])

      read :read_published do
        filter(expr(published == true))
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:published, :boolean, public?: true, default: false)
    end

    relationships do
      has_many(:comments, Comment, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain, otp_app: :ash_json_api, extensions: [AshJsonApi.Domain]

    json_api do
      log_errors?(false)
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

  test "related route uses the configured source read action" do
    published =
      Post
      |> Ash.Changeset.for_create(:create, %{name: "published", published: true})
      |> Ash.create!()

    unpublished =
      Post
      |> Ash.Changeset.for_create(:create, %{name: "unpublished", published: false})
      |> Ash.create!()

    for post <- [published, unpublished] do
      Comment
      |> Ash.Changeset.for_create(:create, %{name: "c", post_id: post.id})
      |> Ash.create!()
    end

    Domain
    |> get("/posts/#{published.id}/comments", status: 200)
    |> assert_data_matches([%{"type" => "comment"}])

    Domain
    |> get("/posts/#{unpublished.id}/comments", status: 404)
  end

  describe "route action resolution" do
    alias AshJsonApi.Controllers.Router
    alias AshJsonApi.Resource.Route

    test "returns nil when the route has no action so controllers can fall back to the primary action" do
      route = %Route{type: :post_to_relationship, method: :post, route: "/:id/relationships/x"}
      assert Router.route_action!(Post, route) == nil
    end

    test "returns the action when it exists on the source resource" do
      route = %Route{type: :get_related, method: :get, route: "/:id/comments", action: :read}
      assert %Ash.Resource.Actions.Read{name: :read} = Router.route_action!(Post, route)
    end

    test "raises a descriptive error when the action does not exist on the resource" do
      route = %Route{type: :get, method: :get, route: "/:id", action: :nope}

      error = assert_raise ArgumentError, fn -> Router.route_action!(Post, route) end
      assert error.message =~ "GET /:id refers to action :nope"
      assert error.message =~ "#{inspect(Post)} has no such action"
    end

    test "explains that related and relationship routes take a source resource action" do
      for type <- [:get_related, :relationship] do
        route = %Route{
          type: type,
          method: :get,
          route: "/:id/comments",
          action: :list,
          relationship: :comments
        }

        error = assert_raise ArgumentError, fn -> Router.route_action!(Post, route) end
        assert error.message =~ "read action on the source resource"
        assert error.message =~ "`read_action` on the `:comments` relationship"
      end
    end
  end
end
