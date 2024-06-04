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
    include_1 =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.create!()

    include_2 =
      Include
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.Changeset.manage_relationship(:include_a, include_1, type: :append_and_remove)
      |> Ash.Changeset.manage_relationship(:include_b, include_1, type: :append_and_remove)
      |> Ash.create!()

    %{include_1: include_1, include_2: include_2}
  end

  test "returns includes successfully", %{include_1: %{id: include_1_id}} do
    conn =
      Domain
      |> get("/includes?include=include_a.include_a.include_a,include_b.include_b.include_b",
        status: 200
      )

    response = conn.resp_body

    assert [
             %{"id" => ^include_1_id}
           ] = response["included"]
  end
end
