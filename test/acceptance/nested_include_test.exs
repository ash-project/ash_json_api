defmodule Test.Acceptance.NestedIncludeTest do
  @moduledoc """
  This test assert that nested includes definition are wrapped in list automatically.
  """

  use ExUnit.Case, async: true

  defmodule Include do
    use Ash.Resource,
      domain: Test.Acceptance.NestedIncludeTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("include")

      includes include_a: [include_a: [:include_a]],
               include_b: [include_b: :include_b],
               children: [:grandchild]

      routes do
        base("/includes")

        index(:read)
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to(:include_a, Include, public?: true)
      belongs_to(:include_b, Include, public?: true)
      has_many(:children, Test.Acceptance.NestedIncludeTest.Child, public?: true)
    end
  end

  defmodule Child do
    use Ash.Resource,
      domain: Test.Acceptance.NestedIncludeTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("child")
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to(:include, Include, public?: true)
      belongs_to(:grandchild, Test.Acceptance.NestedIncludeTest.Grandchild, public?: true)
    end
  end

  defmodule Grandchild do
    use Ash.Resource,
      domain: Test.Acceptance.NestedIncludeTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("grandchild")
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      has_many(:children, Test.Acceptance.NestedIncludeTest.Child, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router(Test.Acceptance.NestedIncludeTest.Router)
      log_errors?(false)
    end

    resources do
      resource(Include)
      resource(Child)
      resource(Grandchild)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    grandchild =
      Grandchild
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.create!()

    children =
      1..3
      |> Enum.map(fn _ ->
        Child
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.Changeset.manage_relationship(:grandchild, grandchild, type: :append_and_remove)
        |> Ash.create!()
      end)

    include_1 =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.Changeset.manage_relationship(:children, children, type: :append_and_remove)
      |> Ash.create!()

    include_2 =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.Changeset.manage_relationship(:include_a, include_1, type: :append_and_remove)
      |> Ash.Changeset.manage_relationship(:include_b, include_1, type: :append_and_remove)
      |> Ash.create!()

    %{include_1: include_1, include_2: include_2, children: children, grandchild: grandchild}
  end

  test "returns includes successfully", %{
    include_1: %{id: include_1_id},
    children: children,
    grandchild: %{id: grandchild_id}
  } do
    conn =
      Domain
      |> get(
        "/includes?include=include_a.include_a.include_a,include_b.include_b.include_b,children.grandchild",
        status: 200
      )

    response = conn.resp_body
    included_ids = Enum.map(response["included"], &Map.get(&1, "id"))

    # 3 children, 1 grandchild, and include_1
    assert Enum.count(included_ids) == 5
    assert Enum.member?(included_ids, grandchild_id)
    assert Enum.member?(included_ids, include_1_id)
    assert Enum.all?(children, fn child -> Enum.member?(included_ids, child.id) end)
  end
end
