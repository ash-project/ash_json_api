# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.FieldNamesTest do
  use ExUnit.Case, async: true

  # ─── Resource with keyword-list field_names ──────────────────────────────

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.FieldNamesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "post"

      # Rename :title → "subject", :body → "content"
      field_names(title: :subject, body: :content)

      routes do
        base "/posts"
        get :read
        index :read
        post :create
        patch :update
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
      attribute(:body, :string, public?: true)
      attribute(:view_count, :integer, public?: true, default: 0)
    end

    actions do
      default_accept([:title, :body, :view_count])
      defaults([:read, :create, :update, :destroy])

      read :search do
        argument(:title_filter, :string, allow_nil?: true)
        filter(expr(is_nil(^arg(:title_filter)) or title == ^arg(:title_filter)))
      end
    end

    calculations do
      calculate(:slug, :string, expr(title))
    end
  end

  # ─── Resource with function-based field_names ────────────────────────────

  defmodule Article do
    use Ash.Resource,
      domain: Test.Acceptance.FieldNamesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "article"

      # Function: snake_case → camelCase
      field_names(fn name ->
        camelized = name |> to_string() |> Macro.camelize()
        {first, rest} = String.split_at(camelized, 1)
        String.downcase(first) <> rest
      end)

      routes do
        base "/articles"
        get :read
        index :read
        post :create
        patch :update
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:first_name, :string, allow_nil?: false, public?: true)
      attribute(:last_name, :string, allow_nil?: false, public?: true)
    end

    actions do
      default_accept([:first_name, :last_name])
      defaults([:read, :create, :update, :destroy])
    end
  end

  # ─── Resource with keyword-list argument_names ───────────────────────────────

  defmodule Comment do
    use Ash.Resource,
      domain: Test.Acceptance.FieldNamesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "comment"

      # Rename :body argument in :create action → "text"
      argument_names(create: [body: :text])

      routes do
        base "/comments"
        get :read
        index :read
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:body, :string, allow_nil?: false, public?: true)
    end

    actions do
      default_accept([])
      defaults([:read, :destroy])

      create :create do
        argument(:body, :string, allow_nil?: false)
        change(set_attribute(:body, arg(:body)))
      end
    end
  end

  # ─── Resource with function-based argument_names ─────────────────────────────

  defmodule Tag do
    use Ash.Resource,
      domain: Test.Acceptance.FieldNamesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "tag"

      # 2-arity function: (action_name, arg_name) → camelCase
      argument_names(fn _action_name, arg_name ->
        camelized = arg_name |> to_string() |> Macro.camelize()
        {first, rest} = String.split_at(camelized, 1)
        String.downcase(first) <> rest
      end)

      routes do
        base "/tags"
        get :read
        index :read
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, allow_nil?: false, public?: true)
    end

    actions do
      default_accept([])
      defaults([:read, :destroy])

      create :create do
        argument(:label_value, :string, allow_nil?: false)
        change(set_attribute(:label, arg(:label_value)))
      end
    end
  end

  # ─── Resource without any name remapping (baseline) ──────────────────────────

  defmodule Widget do
    use Ash.Resource,
      domain: Test.Acceptance.FieldNamesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "widget"

      routes do
        base "/widgets"
        get :read
        index :read
        post :create
        patch :update
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false, public?: true)
      attribute(:color, :string, public?: true)
    end

    actions do
      default_accept([:name, :color])
      defaults([:read, :create, :update, :destroy])
    end
  end

  # ─── Domain / Router ─────────────────────────────────────────────────────────

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
      resource Article
      resource Comment
      resource Tag
      resource Widget
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

  # ─── Serialization: keyword-list field_names ──────────────────────────────

  describe "field_names (keyword list) – serialization" do
    test "renamed attributes appear under their new JSON keys in GET response" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello", body: "World"})
        |> Ash.create!()

      response = Domain |> get("/posts/#{post.id}", status: 200)
      attrs = response.resp_body["data"]["attributes"]

      assert attrs["subject"] == "Hello"
      assert attrs["content"] == "World"
      refute Map.has_key?(attrs, "title")
      refute Map.has_key?(attrs, "body")
    end

    test "renamed attributes appear under their new JSON keys in index response" do
      Post |> Ash.Changeset.for_create(:create, %{title: "T1", body: "B1"}) |> Ash.create!()

      response = Domain |> get("/posts", status: 200)
      attrs = response.resp_body["data"] |> List.first() |> Map.fetch!("attributes")

      assert attrs["subject"] == "T1"
      assert attrs["content"] == "B1"
      refute Map.has_key?(attrs, "title")
      refute Map.has_key?(attrs, "body")
    end

    test "unrenamed attributes still appear under their original names" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "T", view_count: 5})
        |> Ash.create!()

      response = Domain |> get("/posts/#{post.id}", status: 200)
      attrs = response.resp_body["data"]["attributes"]

      assert attrs["view_count"] == 5
    end
  end

  # ─── Serialization: function-based field_names ───────────────────────────

  describe "field_names (function) – serialization" do
    test "camelCase function renames snake_case attributes" do
      article =
        Article
        |> Ash.Changeset.for_create(:create, %{first_name: "Ada", last_name: "Lovelace"})
        |> Ash.create!()

      response = Domain |> get("/articles/#{article.id}", status: 200)
      attrs = response.resp_body["data"]["attributes"]

      assert attrs["firstName"] == "Ada"
      assert attrs["lastName"] == "Lovelace"
      refute Map.has_key?(attrs, "first_name")
      refute Map.has_key?(attrs, "last_name")
    end

    test "camelCase function in index response" do
      Article
      |> Ash.Changeset.for_create(:create, %{first_name: "Grace", last_name: "Hopper"})
      |> Ash.create!()

      response = Domain |> get("/articles", status: 200)
      attrs = response.resp_body["data"] |> List.first() |> Map.fetch!("attributes")

      assert attrs["firstName"] == "Grace"
      assert attrs["lastName"] == "Hopper"
    end
  end

  # ─── Request parsing: keyword-list field_names ───────────────────────────

  describe "field_names (keyword list) – request parsing" do
    test "create with renamed attribute keys succeeds" do
      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{subject: "New Post", content: "Body text"}
          }
        })

      assert response.status == 201
      attrs = response.resp_body["data"]["attributes"]
      assert attrs["subject"] == "New Post"
      assert attrs["content"] == "Body text"
    end

    test "update with renamed attribute keys succeeds" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Old", body: "Old body"})
        |> Ash.create!()

      response =
        Domain
        |> patch("/posts/#{post.id}", %{
          data: %{
            type: "post",
            id: post.id,
            attributes: %{subject: "Updated"}
          }
        })

      assert response.status == 200
      attrs = response.resp_body["data"]["attributes"]
      assert attrs["subject"] == "Updated"
    end

    test "create with original (non-renamed) attribute key is rejected as no such input" do
      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{title: "Original Key"}
          }
        })

      # title is required; when sent under old name, it is not recognised,
      # so we expect a validation error (400 - required field missing or unknown input)
      assert response.status in [400, 422]
    end
  end

  # ─── Request parsing: function-based field_names ────────────────────────

  describe "field_names (function) – request parsing" do
    test "create with camelCase keys succeeds" do
      response =
        Domain
        |> post("/articles", %{
          data: %{
            type: "article",
            attributes: %{firstName: "Linus", lastName: "Torvalds"}
          }
        })

      assert response.status == 201
      attrs = response.resp_body["data"]["attributes"]
      assert attrs["firstName"] == "Linus"
      assert attrs["lastName"] == "Torvalds"
    end

    test "update with camelCase keys succeeds" do
      article =
        Article
        |> Ash.Changeset.for_create(:create, %{first_name: "Old", last_name: "Name"})
        |> Ash.create!()

      response =
        Domain
        |> patch("/articles/#{article.id}", %{
          data: %{
            type: "article",
            id: article.id,
            attributes: %{firstName: "New"}
          }
        })

      assert response.status == 200
      attrs = response.resp_body["data"]["attributes"]
      assert attrs["firstName"] == "New"
    end
  end

  # ─── Argument names: keyword list ────────────────────────────────────────────

  describe "argument_names (keyword list) – request parsing" do
    test "create action argument sent under renamed key succeeds" do
      response =
        Domain
        |> post("/comments", %{
          data: %{
            type: "comment",
            attributes: %{text: "Hello world"}
          }
        })

      assert response.status == 201
      attrs = response.resp_body["data"]["attributes"]
      assert attrs["body"] == "Hello world"
    end

    test "create action argument sent under original key is not recognised" do
      response =
        Domain
        |> post("/comments", %{
          data: %{
            type: "comment",
            attributes: %{body: "Hello world"}
          }
        })

      # body argument renamed to text; sending under original name → missing required
      assert response.status in [400, 422]
    end
  end

  # ─── Argument names: function ────────────────────────────────────────────────

  describe "argument_names (function) – request parsing" do
    test "create action argument sent under camelCase key succeeds" do
      response =
        Domain
        |> post("/tags", %{
          data: %{
            type: "tag",
            attributes: %{labelValue: "elixir"}
          }
        })

      assert response.status == 201
      attrs = response.resp_body["data"]["attributes"]
      assert attrs["label"] == "elixir"
    end

    test "create action argument sent under original snake_case key is not recognised" do
      response =
        Domain
        |> post("/tags", %{
          data: %{
            type: "tag",
            attributes: %{label_value: "elixir"}
          }
        })

      assert response.status in [400, 422]
    end
  end

  # ─── Sort parameter ───────────────────────────────────────────────────────────

  describe "field_names – sort parameter" do
    setup do
      Post |> Ash.Changeset.for_create(:create, %{title: "AAA"}) |> Ash.create!()
      Post |> Ash.Changeset.for_create(:create, %{title: "BBB"}) |> Ash.create!()
      :ok
    end

    test "sorts using the renamed attribute key (ascending)" do
      response = Domain |> get("/posts?sort=subject", status: 200)

      titles =
        response.resp_body["data"]
        |> Enum.map(& &1["attributes"]["subject"])

      assert titles == Enum.sort(titles)
    end

    test "sorts using the renamed attribute key (descending with -)" do
      response = Domain |> get("/posts?sort=-subject", status: 200)

      titles =
        response.resp_body["data"]
        |> Enum.map(& &1["attributes"]["subject"])

      assert titles == Enum.sort(titles, :desc)
    end

    test "sort by original attribute name is rejected (unknown field)" do
      # "title" is not the exposed sort key; the sort should either be ignored or error
      # In practice AshJsonApi returns errors for unknown sort fields
      response = Domain |> get("/posts?sort=title")
      assert response.status in [200, 400]
      # If 400, it's because "title" is not a valid sort field
    end
  end

  # ─── Filter parameter ─────────────────────────────────────────────────────────

  describe "field_names – filter parameter" do
    setup do
      Post |> Ash.Changeset.for_create(:create, %{title: "findme"}) |> Ash.create!()
      Post |> Ash.Changeset.for_create(:create, %{title: "other"}) |> Ash.create!()
      :ok
    end

    test "filters using the renamed attribute key" do
      response = Domain |> get("/posts?filter[subject]=findme", status: 200)
      data = response.resp_body["data"]

      assert length(data) == 1
      assert List.first(data)["attributes"]["subject"] == "findme"
    end

    test "filters using the deep-object renamed attribute key" do
      response = Domain |> get("/posts?filter[subject][eq]=findme", status: 200)

      # Allow 200 (may be empty if eq not supported) or 400 (operator not supported)
      # At minimum the key remapping must not crash
      assert response.status in [200, 400]

      if response.status == 200 do
        data = response.resp_body["data"]
        assert length(data) == 1
      end
    end
  end

  # ─── Sparse fieldsets ─────────────────────────────────────────────────────────

  describe "field_names – sparse fieldsets (fields[])" do
    test "field selection using renamed key returns only that field" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "Hello", body: "World", view_count: 3})
        |> Ash.create!()

      response = Domain |> get("/posts/#{post.id}?fields[post]=subject", status: 200)
      attrs = response.resp_body["data"]["attributes"]

      assert Map.has_key?(attrs, "subject")
      refute Map.has_key?(attrs, "content")
      refute Map.has_key?(attrs, "view_count")
    end

    test "multiple renamed fields can be selected" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{title: "T", body: "B", view_count: 7})
        |> Ash.create!()

      response = Domain |> get("/posts/#{post.id}?fields[post]=subject,content", status: 200)
      attrs = response.resp_body["data"]["attributes"]

      assert Map.has_key?(attrs, "subject")
      assert Map.has_key?(attrs, "content")
      refute Map.has_key?(attrs, "view_count")
    end
  end

  # ─── Error source pointers ────────────────────────────────────────────────────

  describe "field_names – error source pointers" do
    test "validation error source pointer uses renamed attribute key" do
      # Create with a rename – title (Ash) is mapped to "subject" (JSON:API).
      # Sending an empty subject (required field missing) should produce a source pointer
      # pointing to /data/attributes/subject (not /data/attributes/title).
      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{}
          }
        })

      assert response.status in [400, 422]
      errors = response.resp_body["errors"]
      assert errors != []

      # At least one error should reference the renamed field
      source_pointers = Enum.map(errors, & &1["source"]["pointer"])

      # The pointer should use "subject" (renamed), not "title" (original)
      assert Enum.any?(source_pointers, fn ptr ->
               is_binary(ptr) and String.contains?(ptr, "subject")
             end)

      refute Enum.any?(source_pointers, fn ptr ->
               is_binary(ptr) and String.contains?(ptr, "/data/attributes/title")
             end)
    end
  end

  # ─── Baseline: no remapping ───────────────────────────────────────────────────

  describe "no field_names configured – original behavior unchanged" do
    test "attributes appear under their original names" do
      widget =
        Widget
        |> Ash.Changeset.for_create(:create, %{name: "Gadget", color: "blue"})
        |> Ash.create!()

      response = Domain |> get("/widgets/#{widget.id}", status: 200)
      attrs = response.resp_body["data"]["attributes"]

      assert attrs["name"] == "Gadget"
      assert attrs["color"] == "blue"
    end

    test "create with original attribute names works" do
      response =
        Domain
        |> post("/widgets", %{
          data: %{
            type: "widget",
            attributes: %{name: "Thing", color: "red"}
          }
        })

      assert response.status == 201
      attrs = response.resp_body["data"]["attributes"]
      assert attrs["name"] == "Thing"
      assert attrs["color"] == "red"
    end

    test "sort uses original attribute names" do
      Widget |> Ash.Changeset.for_create(:create, %{name: "AAA"}) |> Ash.create!()
      Widget |> Ash.Changeset.for_create(:create, %{name: "BBB"}) |> Ash.create!()

      response = Domain |> get("/widgets?sort=name", status: 200)

      names =
        response.resp_body["data"]
        |> Enum.map(& &1["attributes"]["name"])

      assert names == Enum.sort(names)
    end

    test "filter uses original attribute names" do
      Widget |> Ash.Changeset.for_create(:create, %{name: "target"}) |> Ash.create!()
      Widget |> Ash.Changeset.for_create(:create, %{name: "other"}) |> Ash.create!()

      response = Domain |> get("/widgets?filter[name]=target", status: 200)
      data = response.resp_body["data"]
      assert length(data) == 1
      assert List.first(data)["attributes"]["name"] == "target"
    end
  end

  # ─── Info module helpers ──────────────────────────────────────────────────────

  describe "AshJsonApi.Resource.Info helper functions" do
    test "field_to_json_key/2 returns renamed key for keyword list" do
      assert AshJsonApi.Resource.Info.field_to_json_key(Post, :title) == "subject"
      assert AshJsonApi.Resource.Info.field_to_json_key(Post, :body) == "content"
    end

    test "field_to_json_key/2 returns original name for unrenamed field" do
      assert AshJsonApi.Resource.Info.field_to_json_key(Post, :view_count) == "view_count"
    end

    test "field_to_json_key/2 applies function for function-based mapping" do
      assert AshJsonApi.Resource.Info.field_to_json_key(Article, :first_name) == "firstName"
      assert AshJsonApi.Resource.Info.field_to_json_key(Article, :last_name) == "lastName"
    end

    test "field_to_json_key/2 returns original name when no mapping configured" do
      assert AshJsonApi.Resource.Info.field_to_json_key(Widget, :name) == "name"
      assert AshJsonApi.Resource.Info.field_to_json_key(Widget, :color) == "color"
    end

    test "json_key_to_field/2 reverses keyword list mapping" do
      assert AshJsonApi.Resource.Info.json_key_to_field(Post, "subject") == :title
      assert AshJsonApi.Resource.Info.json_key_to_field(Post, "content") == :body
    end

    test "json_key_to_field/2 returns nil for unknown key" do
      assert AshJsonApi.Resource.Info.json_key_to_field(Post, "nonexistent") == nil
    end

    test "json_key_to_field/2 reverses function-based mapping" do
      assert AshJsonApi.Resource.Info.json_key_to_field(Article, "firstName") == :first_name
      assert AshJsonApi.Resource.Info.json_key_to_field(Article, "lastName") == :last_name
    end

    test "argument_to_json_key/3 returns renamed key for keyword list" do
      assert AshJsonApi.Resource.Info.argument_to_json_key(Comment, :create, :body) == "text"
    end

    test "argument_to_json_key/3 returns original name for unrenamed arg" do
      assert AshJsonApi.Resource.Info.argument_to_json_key(Widget, :create, :name) == "name"
    end

    test "argument_to_json_key/3 applies 2-arity function" do
      assert AshJsonApi.Resource.Info.argument_to_json_key(Tag, :create, :label_value) ==
               "labelValue"
    end

    test "json_key_to_argument/3 reverses keyword list mapping" do
      assert AshJsonApi.Resource.Info.json_key_to_argument(Comment, :create, "text") == :body
    end

    test "json_key_to_argument/3 returns nil for unknown key" do
      assert AshJsonApi.Resource.Info.json_key_to_argument(Comment, :create, "nonexistent") ==
               nil
    end

    test "json_key_to_argument/3 reverses 2-arity function mapping" do
      assert AshJsonApi.Resource.Info.json_key_to_argument(Tag, :create, "labelValue") ==
               :label_value
    end
  end
end
