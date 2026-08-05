# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.FieldVisibilityTest do
  use ExUnit.Case, async: true

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.FieldVisibilityTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("visibility-author")

      routes do
        base("/visibility_authors")
        get(:read)
        index(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false, public?: true)
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.FieldVisibilityTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      primary_read_warning?: false,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("visibility-post")
      includes([:visible_author, :hidden_author])
      paginated_includes([:visible_author, :hidden_author])
      default_fields([:title, :secret, :secret_calc])
      hide_fields([:secret, :secret_calc, :hidden_author])

      routes do
        base("/visibility_posts")
        get(:read)
        index(:read)
        related(:visible_author, :read)
        related(:hidden_author, :read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :update, :destroy])

      read :read do
        primary? true
        prepare(build(load: [:secret_calc, :visible_author, :hidden_author]))
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
      attribute(:secret, :string, allow_nil?: false, public?: true)
    end

    calculations do
      calculate(:secret_calc, :string, concat([:title, :secret], ":"), public?: true)
    end

    relationships do
      belongs_to :visible_author, Test.Acceptance.FieldVisibilityTest.Author do
        allow_nil?(false)
        public?(true)
        attribute_writable?(true)
      end

      belongs_to :hidden_author, Test.Acceptance.FieldVisibilityTest.Author do
        allow_nil?(false)
        public?(true)
        attribute_writable?(true)
      end
    end
  end

  defmodule ShowOnlyPost do
    use Ash.Resource,
      domain: Test.Acceptance.FieldVisibilityTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      primary_read_warning?: false,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("visibility-show-post")
      includes([:visible_author, :extra_author])
      default_fields([:title, :summary, :secret_calc])
      hide_fields([:summary])
      show_fields([:title, :summary, :visible_author])

      routes do
        base("/visibility_show_posts")
        get(:read)
        related(:visible_author, :read)
        related(:extra_author, :read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :update, :destroy])

      read :read do
        primary? true
        prepare(build(load: [:secret_calc, :visible_author, :extra_author]))
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
      attribute(:summary, :string, allow_nil?: false, public?: true)
    end

    calculations do
      calculate(:secret_calc, :string, concat([:title, :summary], ":"), public?: true)
    end

    relationships do
      belongs_to :visible_author, Test.Acceptance.FieldVisibilityTest.Author do
        allow_nil?(false)
        public?(true)
        attribute_writable?(true)
      end

      belongs_to :extra_author, Test.Acceptance.FieldVisibilityTest.Author do
        allow_nil?(false)
        public?(true)
        attribute_writable?(true)
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
    end

    resources do
      resource(Author)
      resource(Post)
      resource(ShowOnlyPost)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    visible_author =
      Author
      |> Ash.Changeset.for_create(:create, %{name: "visible"})
      |> Ash.create!()

    hidden_author =
      Author
      |> Ash.Changeset.for_create(:create, %{name: "hidden"})
      |> Ash.create!()

    post =
      Post
      |> Ash.Changeset.for_create(:create, %{
        title: "Public",
        secret: "private",
        visible_author_id: visible_author.id,
        hidden_author_id: hidden_author.id
      })
      |> Ash.create!()

    show_only_post =
      ShowOnlyPost
      |> Ash.Changeset.for_create(:create, %{
        title: "Shown",
        summary: "not shown",
        visible_author_id: visible_author.id,
        extra_author_id: hidden_author.id
      })
      |> Ash.create!()

    %{post: post, show_only_post: show_only_post, visible_author: visible_author}
  end

  test "hidden fields are omitted from get responses", %{post: post} do
    response =
      Domain
      |> get("/visibility_posts/#{post.id}", status: 200)

    attributes = response.resp_body["data"]["attributes"]
    relationships = response.resp_body["data"]["relationships"]

    assert attributes["title"] == "Public"
    refute Map.has_key?(attributes, "secret")
    refute Map.has_key?(attributes, "secret_calc")

    assert Map.has_key?(relationships, "visible_author")
    refute Map.has_key?(relationships, "hidden_author")
  end

  test "hidden fields are omitted from index responses", %{post: post} do
    response =
      Domain
      |> get("/visibility_posts", status: 200)

    data = Enum.find(response.resp_body["data"], &(&1["id"] == post.id))
    attributes = data["attributes"]
    relationships = data["relationships"]

    assert attributes["title"] == "Public"
    refute Map.has_key?(attributes, "secret")
    refute Map.has_key?(attributes, "secret_calc")

    assert Map.has_key?(relationships, "visible_author")
    refute Map.has_key?(relationships, "hidden_author")
  end

  test "hidden fields cannot be requested with sparse fieldsets", %{post: post} do
    Domain
    |> get("/visibility_posts/#{post.id}?fields[visibility-post]=secret", status: 400)
    |> assert_has_error(%{
      "code" => "invalid_field"
    })
  end

  test "hidden fields cannot be requested with derived sort" do
    Domain
    |> get("/visibility_posts?sort=secret", status: 400)
    |> assert_has_error(%{
      "code" => "invalid_sort"
    })
  end

  test "hidden relationships cannot be included", %{post: post} do
    Domain
    |> get("/visibility_posts/#{post.id}?include=hidden_author", status: 400)
    |> assert_has_error(%{
      "code" => "invalid_includes"
    })
  end

  test "visible relationships can still be included", %{
    post: post,
    visible_author: visible_author
  } do
    response =
      Domain
      |> get("/visibility_posts/#{post.id}?include=visible_author", status: 200)

    assert [%{"id" => visible_author_id, "type" => "visibility-author"}] =
             response.resp_body["included"]

    assert visible_author_id == visible_author.id
  end

  test "hidden relationship routes are not exposed", %{post: post} do
    Domain
    |> get("/visibility_posts/#{post.id}/hidden_author", status: 404)
  end

  test "visible relationship routes are still exposed", %{
    post: post,
    visible_author: visible_author
  } do
    response =
      Domain
      |> get("/visibility_posts/#{post.id}/visible_author", status: 200)

    assert response.resp_body["data"]["id"] == visible_author.id
    assert response.resp_body["data"]["type"] == "visibility-author"
  end

  test "show_fields only exposes allowlisted fields and hide_fields wins", %{
    show_only_post: post
  } do
    response =
      Domain
      |> get("/visibility_show_posts/#{post.id}", status: 200)

    attributes = response.resp_body["data"]["attributes"]
    relationships = response.resp_body["data"]["relationships"]

    assert attributes["title"] == "Shown"
    refute Map.has_key?(attributes, "summary")
    refute Map.has_key?(attributes, "secret_calc")

    assert Map.has_key?(relationships, "visible_author")
    refute Map.has_key?(relationships, "extra_author")
  end

  test "show_fields rejects non-allowlisted sparse fieldsets", %{show_only_post: post} do
    Domain
    |> get("/visibility_show_posts/#{post.id}?fields[visibility-show-post]=secret_calc",
      status: 400
    )
    |> assert_has_error(%{
      "code" => "invalid_field"
    })
  end

  test "hide_fields rejects sparse fieldsets even when the field is in show_fields", %{
    show_only_post: post
  } do
    Domain
    |> get("/visibility_show_posts/#{post.id}?fields[visibility-show-post]=summary", status: 400)
    |> assert_has_error(%{
      "code" => "invalid_field"
    })
  end

  test "show_fields rejects non-allowlisted includes", %{show_only_post: post} do
    Domain
    |> get("/visibility_show_posts/#{post.id}?include=extra_author", status: 400)
    |> assert_has_error(%{
      "code" => "invalid_includes"
    })
  end

  test "show_fields hides non-allowlisted relationship routes", %{show_only_post: post} do
    Domain
    |> get("/visibility_show_posts/#{post.id}/extra_author", status: 404)
  end
end
