# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.OpenApiConstraintsTest do
  @moduledoc """
  Type constraints are documented in the generated OpenAPI schemas.
  See https://github.com/ash-project/ash_json_api/issues/484
  """
  use ExUnit.Case, async: true

  defmodule Widget do
    use Ash.Resource,
      domain: Test.Acceptance.OpenApiConstraintsTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("widget")

      routes do
        base("/widgets")
        index(:read)
        index(:by_widget, route: "/by_widget/:widget_id")
        post(:create)
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :create])

      read :by_widget do
        argument(:widget_id, :integer,
          allow_nil?: false,
          public?: true,
          constraints: [min: 0, max: 2_147_483_647]
        )
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:count, :integer, public?: true, constraints: [min: 0, max: 100])
      attribute(:ratio, :float, public?: true, constraints: [greater_than: 0.0, max: 1.0])
      attribute(:name, :string, public?: true, constraints: [min_length: 2, max_length: 50])

      attribute(:code, :string,
        public?: true,
        constraints: [max_length: 10, length_count: :bytes]
      )

      attribute(:tags, {:array, :string},
        public?: true,
        constraints: [min_length: 1, max_length: 5, items: [max_length: 20]]
      )

      attribute(:price, :decimal, public?: true, constraints: [min: 0])
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

  setup_all do
    %{spec: AshJsonApi.Controllers.OpenApi.spec(%{private: %{}}, domains: [Domain])}
  end

  defp attributes(spec) do
    spec.components.schemas["widget"].properties.attributes.properties
    |> Map.new(fn {key, schema} -> {key, unwrap_nullable(schema)} end)
  end

  defp create_attributes(spec) do
    [media_type] = Map.values(spec.paths["/widgets"].post.requestBody.content)

    media_type.schema.properties.data.properties.attributes.properties
    |> Map.new(fn {key, schema} -> {key, unwrap_nullable(schema)} end)
  end

  defp unwrap_nullable(%{"anyOf" => [schema, %{"type" => "null"}]}), do: schema
  defp unwrap_nullable(schema), do: schema

  test "integer min and max become minimum and maximum", %{spec: spec} do
    for attrs <- [attributes(spec), create_attributes(spec)] do
      assert %{minimum: 0, maximum: 100, exclusiveMinimum: nil} = attrs["count"]
    end
  end

  test "integer constraints on a path param are documented", %{spec: spec} do
    param =
      Enum.find(
        spec.paths["/widgets/by_widget/{widget_id}"].get.parameters,
        &(&1.name == "widget_id")
      )

    assert %{in: :path, schema: %{type: :integer, minimum: 0, maximum: 2_147_483_647}} = param
  end

  test "float greater_than becomes an exclusive minimum", %{spec: spec} do
    for attrs <- [attributes(spec), create_attributes(spec)] do
      assert %{minimum: +0.0, exclusiveMinimum: true, maximum: 1.0, exclusiveMaximum: nil} =
               attrs["ratio"]
    end
  end

  test "string min_length and max_length become minLength and maxLength", %{spec: spec} do
    for attrs <- [attributes(spec), create_attributes(spec)] do
      assert %{minLength: 2, maxLength: 50} = attrs["name"]
    end
  end

  test "string lengths counted in bytes are left out", %{spec: spec} do
    for attrs <- [attributes(spec), create_attributes(spec)] do
      assert %{type: :string, maxLength: nil} = attrs["code"]
    end
  end

  test "array lengths become minItems and maxItems, and item constraints apply", %{spec: spec} do
    for attrs <- [attributes(spec), create_attributes(spec)] do
      assert %{type: :array, minItems: 1, maxItems: 5, items: %{maxLength: 20}} = attrs["tags"]
    end
  end

  test "decimal bounds are left out", %{spec: spec} do
    for attrs <- [attributes(spec), create_attributes(spec)] do
      assert %{type: :string, minimum: nil} = attrs["price"]
    end
  end

  test "filter schemas don't carry the field's bounds", %{spec: spec} do
    filter = spec.components.schemas["widget-filter-count"]

    for {_operator, schema} <- filter.properties, match?(%{type: :integer}, schema) do
      assert %{minimum: nil, maximum: nil} = schema
    end

    assert %{type: :integer} = filter.properties.greater_than
  end
end
