# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.CustomTypeWriteSchemaTest do
  @moduledoc """
  Regression test for https://github.com/ash-project/ash_json_api/issues/447

  Custom types can return atom-keyed maps from `json_schema/1`/`json_write_schema/1`
  (e.g. `AshMoney.Types.Money`). JsonXema silently ignores atom-keyed schema
  keywords, so constraints like `pattern` were not enforced by `validate_body`.
  """
  use ExUnit.Case, async: true

  defmodule Money do
    # Mimics AshMoney.Types.Money: an atom-keyed schema with a pattern
    # meant to reject scientific notation before cast.
    use Ash.Type.NewType, subtype_of: :map
    use AshJsonApi.Type

    @impl AshJsonApi.Type
    def json_schema(_constraints) do
      %{
        type: "object",
        properties: %{
          amount: %{type: "string", pattern: "^-?\\d+(\\.\\d+)?$"},
          currency: %{type: "string"}
        },
        required: ["amount", "currency"]
      }
    end
  end

  defmodule Product do
    use Ash.Resource,
      domain: Test.Acceptance.CustomTypeWriteSchemaTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "product"

      routes do
        base "/products"
        get :read
        post :create
        patch :update
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false, public?: true)
      attribute(:price, Money, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:read, :create, :update, :destroy])
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? false
      log_errors? false
    end

    resources do
      resource Product
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

  describe "custom type json_write_schema with atom keys" do
    test "constraints are enforced on create" do
      response =
        Domain
        |> post(
          "/products",
          %{
            data: %{
              type: "product",
              attributes: %{
                name: "widget",
                price: %{amount: "1E999999999", currency: "USD"}
              }
            }
          },
          status: 400
        )

      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "invalid_body"
      assert error["source"] == %{"pointer" => "/data/attributes/price"}
    end

    test "constraints are enforced on update" do
      product =
        Product
        |> Ash.Changeset.for_create(:create, %{
          name: "widget",
          price: %{amount: "10.00", currency: "USD"}
        })
        |> Ash.create!()

      response =
        Domain
        |> patch(
          "/products/#{product.id}",
          %{
            data: %{
              id: product.id,
              type: "product",
              attributes: %{
                price: %{amount: "1E999999999", currency: "USD"}
              }
            }
          },
          status: 400
        )

      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "invalid_body"
      assert error["source"] == %{"pointer" => "/data/attributes/price"}
    end

    test "valid input still passes" do
      Domain
      |> post(
        "/products",
        %{
          data: %{
            type: "product",
            attributes: %{
              name: "widget",
              price: %{amount: "100.00", currency: "USD"}
            }
          }
        },
        status: 201
      )
    end
  end
end
