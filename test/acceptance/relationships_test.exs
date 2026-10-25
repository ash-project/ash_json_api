# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Acceptance.RelationshipsTest do
  use ExUnit.Case, async: true

  require Ash.Query

  defmodule Tag do
    use Ash.Resource,
      domain: AshJsonApi.Acceptance.RelationshipsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("tag")

      routes do
        # Only needed for type registration; relationship tests hit person route
        index(:read, route: "/tags")
      end
    end

    actions do
      defaults([:read])

      create :create do
        primary?(true)
        accept([:name])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false)
    end
  end

  defmodule PersonTag do
    use Ash.Resource,
      domain: AshJsonApi.Acceptance.RelationshipsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("person_tag")
    end

    actions do
      defaults([:create, :read, :destroy])

      update :update do
        accept([:note])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:note, :string)
    end

    relationships do
      belongs_to(:person, AshJsonApi.Acceptance.RelationshipsTest.Person, allow_nil?: false)
      belongs_to(:tag, AshJsonApi.Acceptance.RelationshipsTest.Tag, allow_nil?: false)
    end
  end

  defmodule Person do
    use Ash.Resource,
      domain: AshJsonApi.Acceptance.RelationshipsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("person")

      relationship_meta_in(tags: [note: :note])

      relationship_meta_out(tags: [note_out: :note])

      routes do
        base("/people")
        relationship :tags, :read
        relationship :best_friend, :read
        patch_relationship(:best_friend)
        patch(:update, relationship_arguments: [:best_friend])
        # Exercise the relationship POST route
        post_to_relationship(:tags)
        patch_relationship(:tags)
        delete_from_relationship(:tags)
      end
    end

    actions do
      defaults([:read, :destroy])

      update :update do
        primary?(true)
        require_atomic?(false)
        accept([:name])
        argument(:tags, {:array, :uuid})
        argument(:best_friend, :map)
        change(manage_relationship(:tags, type: :append_and_remove))
        change(manage_relationship(:best_friend, type: :append_and_remove))
      end

      create :create do
        primary?(true)
        accept([:name])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false)
    end

    relationships do
      belongs_to(:best_friend, __MODULE__, public?: true)

      many_to_many :tags, AshJsonApi.Acceptance.RelationshipsTest.Tag do
        public?(true)
        through(AshJsonApi.Acceptance.RelationshipsTest.PersonTag)
        source_attribute_on_join_resource(:person_id)
        destination_attribute_on_join_resource(:tag_id)
      end
    end
  end

  defmodule Domain do
    use Ash.Domain, extensions: [AshJsonApi.Domain]

    json_api do
      authorize?(false)
    end

    resources do
      resource(AshJsonApi.Acceptance.RelationshipsTest.Person)
      resource(AshJsonApi.Acceptance.RelationshipsTest.Tag)
      resource(AshJsonApi.Acceptance.RelationshipsTest.PersonTag)
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

  @domain Domain
  @router Router

  test "the relationship route for a to-one relationship returns its resource identifier" do
    {:ok, friend} =
      Person
      |> Ash.Changeset.for_create(:create, %{name: "friend"})
      |> Ash.create()

    {:ok, person} =
      Person
      |> Ash.Changeset.for_create(:create, %{name: "person"})
      |> Ash.Changeset.force_change_attribute(:best_friend_id, friend.id)
      |> Ash.create()

    @domain
    |> get("/people/#{person.id}/relationships/best_friend", router: @router, status: 200)
    |> assert_data_equals(%{"type" => "person", "id" => friend.id})

    @domain
    |> get("/people/#{friend.id}/relationships/best_friend", router: @router, status: 200)
    |> assert_data_equals(nil)
  end

  describe "patching a to-one relationship" do
    setup do
      [friend, other_friend] =
        for name <- ["friend", "other friend"] do
          Person
          |> Ash.Changeset.for_create(:create, %{name: name})
          |> Ash.create!()
        end

      person =
        Person
        |> Ash.Changeset.for_create(:create, %{name: "person"})
        |> Ash.Changeset.force_change_attribute(:best_friend_id, friend.id)
        |> Ash.create!()

      %{person: person, other_friend: other_friend}
    end

    test "sets it with a resource identifier", %{person: person, other_friend: other_friend} do
      @domain
      |> patch(
        "/people/#{person.id}/relationships/best_friend",
        %{"data" => %{"type" => "person", "id" => other_friend.id}},
        router: @router,
        status: 200
      )
      |> assert_data_equals(%{"type" => "person", "id" => other_friend.id})

      assert Ash.get!(Person, person.id).best_friend_id == other_friend.id
    end

    test "sets it with a list of one resource identifier", %{
      person: person,
      other_friend: other_friend
    } do
      @domain
      |> patch(
        "/people/#{person.id}/relationships/best_friend",
        %{"data" => [%{"type" => "person", "id" => other_friend.id}]},
        router: @router,
        status: 200
      )
      |> assert_data_equals(%{"type" => "person", "id" => other_friend.id})

      assert Ash.get!(Person, person.id).best_friend_id == other_friend.id
    end

    test "clears it with null", %{person: person} do
      @domain
      |> patch("/people/#{person.id}/relationships/best_friend", %{"data" => nil},
        router: @router,
        status: 200
      )
      |> assert_data_equals(nil)

      assert is_nil(Ash.get!(Person, person.id).best_friend_id)
    end

    test "clears it with null in a relationship argument", %{person: person} do
      @domain
      |> patch(
        "/people/#{person.id}",
        %{
          "data" => %{
            "type" => "person",
            "id" => person.id,
            "relationships" => %{"best_friend" => %{"data" => nil}}
          }
        },
        router: @router,
        status: 200
      )

      assert is_nil(Ash.get!(Person, person.id).best_friend_id)
    end
  end

  test "post_to_relationship accepts resource identifiers with id only" do
    {:ok, tag} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t1"})
      |> Ash.create()

    {:ok, person} =
      Person
      |> Ash.Changeset.for_create(:create, %{name: "p1"})
      |> Ash.create()

    body = %{
      "data" => [
        %{"type" => "tag", "id" => tag.id}
      ]
    }

    @domain
    |> post(
      "/people/#{person.id}/relationships/tags",
      body,
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [tag.id])

    @domain
    |> get(
      "/people/#{person.id}/relationships/tags",
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [tag.id])
  end

  test "post_to_relationship accepts resource identifiers with meta" do
    {:ok, tag} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t2"})
      |> Ash.create()

    {:ok, person} =
      Person
      |> Ash.Changeset.for_create(:create, %{name: "p2"})
      |> Ash.create()

    body = %{
      "data" => [
        %{"type" => "tag", "id" => tag.id, "meta" => %{"note" => "any", "ignored" => "value"}}
      ]
    }

    response =
      @domain
      |> post(
        "/people/#{person.id}/relationships/tags",
        body,
        router: @router,
        status: 200
      )

    assert_valid_resource_objects(response, "tag", [tag.id])

    assert %{
             "data" => [
               %{
                 "id" => id,
                 "type" => "tag",
                 "meta" => meta
               }
             ]
           } = response.resp_body

    assert id == tag.id
    assert Map.has_key?(meta, "note_out")
    refute Map.get(meta, "note_out") == "any"
    refute Map.has_key?(meta, "ignored")
    refute Map.has_key?(meta, "note")
  end

  test "post_to_relationship accepts multiple identifiers" do
    {:ok, t1} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t1"})
      |> Ash.create()

    {:ok, t2} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t2"})
      |> Ash.create()

    {:ok, person} =
      Person
      |> Ash.Changeset.for_create(:create, %{name: "p2"})
      |> Ash.create()

    body = %{
      "data" => [
        %{"type" => "tag", "id" => t1.id},
        %{"type" => "tag", "id" => t2.id}
      ]
    }

    @domain
    |> post(
      "/people/#{person.id}/relationships/tags",
      body,
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [t1.id, t2.id])

    @domain
    |> get(
      "/people/#{person.id}/relationships/tags",
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [t1.id, t2.id])
  end

  test "patch_to_relationship replaces identifiers with provided set" do
    {:ok, t1} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t_patch_1"})
      |> Ash.create()

    {:ok, t2} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t_patch_2"})
      |> Ash.create()

    {:ok, person} =
      Person
      |> Ash.Changeset.for_create(:create, %{name: "p_patch"})
      |> Ash.create()

    @domain
    |> post(
      "/people/#{person.id}/relationships/tags",
      %{"data" => [%{"type" => "tag", "id" => t1.id}]},
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [t1.id])

    @domain
    |> patch(
      "/people/#{person.id}/relationships/tags",
      %{"data" => [%{"type" => "tag", "id" => t1.id}, %{"type" => "tag", "id" => t2.id}]},
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [t1.id, t2.id])

    @domain
    |> get(
      "/people/#{person.id}/relationships/tags",
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [t1.id, t2.id])
  end

  test "delete_from_relationship removes only specified identifiers" do
    {:ok, t1} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t_delete_1"})
      |> Ash.create()

    {:ok, t2} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t_delete_2"})
      |> Ash.create()

    {:ok, t3} =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "t_delete_3"})
      |> Ash.create()

    {:ok, person} =
      Person
      |> Ash.Changeset.for_create(:create, %{name: "p_delete"})
      |> Ash.create()

    @domain
    |> post(
      "/people/#{person.id}/relationships/tags",
      %{
        "data" => [
          %{"type" => "tag", "id" => t1.id},
          %{"type" => "tag", "id" => t2.id},
          %{"type" => "tag", "id" => t3.id}
        ]
      },
      router: @router,
      status: 200
    )
    |> assert_valid_resource_objects("tag", [t1.id, t2.id, t3.id])

    # when deleting, the response contains the remaining tags
    @domain
    |> delete(
      "/people/#{person.id}/relationships/tags",
      router: @router,
      status: 200,
      body: %{"data" => [%{"type" => "tag", "id" => t1.id}]}
    )
    |> assert_valid_resource_objects("tag", [t2.id, t3.id])
  end
end
