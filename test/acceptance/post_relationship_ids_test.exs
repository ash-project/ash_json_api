defmodule AshJsonApi.Acceptance.PostRelationshipIdsTest do
  use ExUnit.Case, async: false

  defmodule Tag do
    use Ash.Resource,
      domain: AshJsonApi.Acceptance.PostRelationshipIdsTest.Domain,
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
      domain: AshJsonApi.Acceptance.PostRelationshipIdsTest.Domain,
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
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to(:person, AshJsonApi.Acceptance.PostRelationshipIdsTest.Person, allow_nil?: false)
      belongs_to(:tag, AshJsonApi.Acceptance.PostRelationshipIdsTest.Tag, allow_nil?: false)
    end
  end

  defmodule Person do
    use Ash.Resource,
      domain: AshJsonApi.Acceptance.PostRelationshipIdsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("person")

      routes do
        base("/people")
        # Exercise the relationship POST route
        post_to_relationship(:tags)
      end
    end

    actions do
      defaults([:read, :destroy])

      update :update do
        primary?(true)
        require_atomic?(false)
        accept([:name])
        argument(:tags, {:array, :uuid})
        change(manage_relationship(:tags, type: :append_and_remove))
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
      many_to_many :tags, AshJsonApi.Acceptance.PostRelationshipIdsTest.Tag do
        public?(true)
        through(AshJsonApi.Acceptance.PostRelationshipIdsTest.PersonTag)
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
      resource(AshJsonApi.Acceptance.PostRelationshipIdsTest.Person)
      resource(AshJsonApi.Acceptance.PostRelationshipIdsTest.Tag)
      resource(AshJsonApi.Acceptance.PostRelationshipIdsTest.PersonTag)
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
        %{"type" => "tag", "id" => tag.id, "meta" => %{"note" => "any"}}
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
  end
end
