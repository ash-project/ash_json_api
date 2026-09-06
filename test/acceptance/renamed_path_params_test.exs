# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.RenamedPathParamsTest do
  @moduledoc """
  Path parameters must resolve to action arguments (and attributes) through the
  `argument_names` / `field_names` mappings. See https://github.com/ash-project/ash_json_api/issues/454
  """
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.RenamedPathParamsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "post"

      argument_names(
        get_by_id: [post_id: :postId],
        touch: [post_id: :postId],
        say_hello: [to: :recipient]
      )

      routes do
        base "/posts"
        get :get_by_id, route: "/:postId"
        patch :touch, route: "/:postId/touch"
        route(:get, "/say_hello/:recipient", :say_hello)
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
    end

    actions do
      default_accept([:title])
      defaults([:read, :create])

      read :get_by_id do
        get?(true)
        argument(:post_id, :uuid, allow_nil?: false)
        filter(expr(id == ^arg(:post_id)))
      end

      action :touch, :struct do
        constraints(instance_of: __MODULE__)
        argument(:post_id, :uuid, allow_nil?: false)

        run(fn input, _ ->
          Ash.get(__MODULE__, input.arguments.post_id)
        end)
      end

      action :say_hello, :string do
        argument(:to, :string, allow_nil?: false)

        run(fn input, _ ->
          {:ok, "Hello, #{input.arguments.to}!"}
        end)
      end
    end
  end

  defmodule CamelizedAuthor do
    use Ash.Resource,
      domain: Test.Acceptance.RenamedPathParamsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "author"

      argument_names :camelize

      routes do
        base "/authors"
        # raw argument names in routes keep working when a mapping is configured
        get :get_by_id, route: "/:author_id"
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false, public?: true)
    end

    actions do
      default_accept([:name])
      defaults([:read, :create])

      read :get_by_id do
        get?(true)
        argument(:author_id, :uuid, allow_nil?: false)
        filter(expr(id == ^arg(:author_id)))
      end
    end
  end

  defmodule RenamedIdPost do
    use Ash.Resource,
      domain: Test.Acceptance.RenamedPathParamsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "renamed_id_post"

      field_names(id: :postId)

      routes do
        base "/renamed_id_posts"
        get :read, route: "/:postId"
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
    end

    actions do
      default_accept([:title])
      defaults([:read, :create])
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? false
      log_errors? false
    end

    resources do
      resource Post
      resource CamelizedAuthor
      resource RenamedIdPost
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

  describe "renamed argument path params" do
    test "a read action argument can be referenced by its renamed path param" do
      post = Ash.create!(Post, %{title: "foo"})

      Domain
      |> get("/posts/#{post.id}", status: 200)
      |> assert_attribute_equals("title", "foo")
    end

    test "a missing record still results in a 404" do
      Domain
      |> get("/posts/#{Ash.UUID.generate()}", status: 404)
    end

    test "a generic action argument can be referenced by its renamed path param" do
      assert Domain
             |> get("/posts/say_hello/world", status: 200)
             |> Map.get(:resp_body) == "Hello, world!"
    end

    test "a patch generic action argument can be referenced by its renamed path param" do
      post = Ash.create!(Post, %{title: "foo"})

      Domain
      |> patch("/posts/#{post.id}/touch", %{data: %{type: "post", attributes: %{}}}, status: 200)
      |> assert_attribute_equals("title", "foo")
    end

    test "raw argument names in routes keep working when a mapping is configured" do
      author = Ash.create!(CamelizedAuthor, %{name: "Zach"})

      Domain
      |> get("/authors/#{author.id}", status: 200)
      |> assert_attribute_equals("name", "Zach")
    end
  end

  describe "renamed attribute path params" do
    test "an attribute can be referenced by its renamed path param" do
      post = Ash.create!(RenamedIdPost, %{title: "foo"})

      Domain
      |> get("/renamed_id_posts/#{post.id}", status: 200)
      |> assert_attribute_equals("title", "foo")
    end
  end

  describe "schema" do
    test "renamed path arguments are excluded from the request body schema" do
      %{"links" => links} = AshJsonApi.JsonSchema.generate([Domain])

      touch_link = Enum.find(links, &String.starts_with?(&1["href"], "/posts/{postId}/touch"))
      assert touch_link

      body_attributes = touch_link["schema"]["properties"]["data"]["properties"]["attributes"]
      refute Map.has_key?(body_attributes["properties"] || %{}, "postId")
      refute Map.has_key?(body_attributes["properties"] || %{}, "post_id")
    end

    test "renamed path arguments are marked as path parameters in the OpenAPI spec" do
      spec = AshJsonApi.Controllers.OpenApi.spec(%{private: %{}}, domains: [Domain])

      %{get: operation} = spec.paths["/posts/say_hello/{recipient}"]

      assert [%{name: "recipient", in: :path, required: true}] =
               Enum.filter(operation.parameters, &(&1.in == :path))

      refute Enum.any?(operation.parameters, &(&1.in == :query && to_string(&1.name) == "to"))

      %{get: operation} = spec.paths["/posts/{postId}"]

      assert [%{name: "postId", required: true}] =
               Enum.filter(operation.parameters, &(&1.in == :path))

      refute Enum.any?(
               operation.parameters,
               &(&1.in == :query && to_string(&1.name) == "post_id")
             )

      %{get: operation} = spec.paths["/authors/{author_id}"]

      assert [%{name: "author_id", required: true}] =
               Enum.filter(operation.parameters, &(&1.in == :path))

      refute Enum.any?(
               operation.parameters,
               &(&1.in == :query && &1.name in ["authorId", "author_id"])
             )
    end
  end
end
