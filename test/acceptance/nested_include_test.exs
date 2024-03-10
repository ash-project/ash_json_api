defmodule Test.Acceptance.NestedIncludeTest do
  @moduledoc """
  This test assert that nested includes definition are wrapped in list automatically.
  """

  use ExUnit.Case, async: true

  defmodule Include do
    use Ash.Resource,
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
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to(:include_a, Include)
      belongs_to(:include_b, Include)
    end
  end

  defmodule Registry do
    use Ash.Registry

    entries do
      entry(Include)
    end
  end

  defmodule Api do
    use Ash.Api,
      extensions: [
        AshJsonApi.Api
      ]

    json_api do
      router(Test.Acceptance.NestedIncludeTest.Router)
      log_errors?(false)
    end

    resources do
      registry(Registry)
    end
  end

  defmodule Router do
    use AshJsonApi.Api.Router, api: Api
  end

  import AshJsonApi.Test

  setup do
    include =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Api.create!()

    include =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.Changeset.manage_relationship(:include_a, include, type: :append_and_remove)
      |> Ash.Changeset.manage_relationship(:include_b, include, type: :append_and_remove)

    %{include: include}
  end

  test "returns includes successfully", %{include: include} do
    Api
    |> get("/includes?include=include_a.include_a.include_a,include_b.include_b.include_b",
      status: 200
    )
  end
end
