# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.RouterTest do
  use ExUnit.Case, async: true

  defmodule Person do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      domain: Test.Acceptance.RouterTest.Personnel,
      extensions: [
        AshJsonApi.Resource
      ]

    json_api do
      type("person")

      routes do
        base("/people")
        get(:read)
        index(:read)
        post(:create)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end
  end

  defmodule Personnel do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Person)
    end
  end

  defmodule Item do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      domain: Test.Acceptance.RouterTest.Inventory,
      extensions: [
        AshJsonApi.Resource
      ]

    json_api do
      type("item")

      routes do
        base("/items")
        get(:read)
        index(:read)
        post(:create)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end
  end

  defmodule Inventory do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Item)
    end
  end

  defmodule Router do
    use AshJsonApi.Router,
      domains: [Test.Acceptance.RouterTest.Personnel, Test.Acceptance.RouterTest.Inventory],
      json_schema: "/json_schema",
      open_api: "/open_api"
  end

  setup do
    Application.put_env(:ash_json_api, Inventory, json_api: [test_router: Router])
    Application.put_env(:ash_json_api, Personnel, json_api: [test_router: Router])

    :ok
  end

  describe "POST /people" do
    test "is routed to the Person resource's create action" do
      response =
        AshJsonApi.Test.post(Test.Acceptance.RouterTest.Personnel, "/people", %{
          data: %{type: "person", attributes: %{name: "Alice"}}
        })

      assert response.status == 201
    end
  end

  describe "POST /items" do
    test "is routed to the Item resource's create action" do
      response =
        AshJsonApi.Test.post(Test.Acceptance.RouterTest.Inventory, "/items", %{
          data: %{type: "item", attributes: %{name: "Sword"}}
        })

      assert response.status == 201
    end
  end
end
