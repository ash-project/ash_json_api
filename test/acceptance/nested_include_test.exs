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
               include_b: [include_b: :include_b]

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
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    include =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.create!()

    include =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.Changeset.manage_relationship(:include_a, include, type: :append_and_remove)
      |> Ash.Changeset.manage_relationship(:include_b, include, type: :append_and_remove)

    %{include: include}
  end

  test "returns includes successfully", %{include: _include} do
    Domain
    |> get("/includes?include=include_a.include_a.include_a,include_b.include_b.include_b",
      status: 200
    )
  end
end
