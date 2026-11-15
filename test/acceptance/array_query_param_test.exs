# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.ArrayQueryParamTest do
  @moduledoc """
  Array query arguments are documented under the `name[]` form that Plug
  decodes as a list. See https://github.com/ash-project/ash_json_api/issues/480
  """
  use ExUnit.Case, async: true

  defmodule Widget do
    use Ash.Resource,
      domain: Test.Acceptance.ArrayQueryParamTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("widget")

      routes do
        base("/widgets")
        index(:by_numbers, route: "/by_numbers")
        route(:get, "/count", :count)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create])

      read :by_numbers do
        argument(:numbers, {:array, :integer}, allow_nil?: false, public?: true)
        argument(:label, :string, public?: true)
        filter(expr(number in ^arg(:numbers)))
      end

      action :count, :integer do
        argument(:names, {:array, :string}, allow_nil?: false, public?: true)
        run(fn input, _ -> {:ok, length(input.arguments.names)} end)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:number, :integer, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize?(false)
    end

    resources do
      resource(Widget)
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

  describe "OpenAPI" do
    setup do
      %{spec: AshJsonApi.Controllers.OpenApi.spec(%{private: %{}}, domains: [Domain])}
    end

    test "an array argument on an index route is documented as name[]", %{spec: spec} do
      names = Enum.map(spec.paths["/widgets/by_numbers"].get.parameters, & &1.name)

      assert "numbers[]" in names
      refute "numbers" in names
      assert "label" in names
    end

    test "an array argument on a generic get route is documented as name[]", %{spec: spec} do
      names = Enum.map(spec.paths["/widgets/count"].get.parameters, & &1.name)

      assert "names[]" in names
      refute "names" in names
    end
  end

  test "the documented form is decoded as a list on an index route" do
    for number <- [1, 2, 3] do
      Widget
      |> Ash.Changeset.for_create(:create, %{number: number})
      |> Ash.create!()
    end

    response = Domain |> get("/widgets/by_numbers?numbers[]=1&numbers[]=3", status: 200)

    assert response.resp_body["data"]
           |> Enum.map(& &1["attributes"]["number"])
           |> Enum.sort() == [1, 3]
  end

  test "the documented form is decoded as a list on a generic get route" do
    response = Domain |> get("/widgets/count?names[]=a&names[]=b", status: 200)
    assert response.resp_body == 2
  end
end
