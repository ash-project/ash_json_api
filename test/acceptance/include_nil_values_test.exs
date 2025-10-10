# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.IncludeNilValuesTest do
  @moduledoc """
  This test tries to assert that the following things apply:
  - If a resource does not set include_nil_values? the serializer uses the value set for its API.
  - If the API does not set include_nil_values? the serializer uses the default value which is true.
  - If a resource sets include_nil_values? to false the serializer does not include nil values.
  """

  use ExUnit.Case, async: true

  defmodule Include do
    use Ash.Resource,
      domain: Test.Acceptance.IncludeNilValuesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("include")

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
      attribute(:foo, :string, public?: true)
      attribute(:bar, :string, public?: true)
    end
  end

  defmodule Exclude do
    use Ash.Resource,
      domain: Test.Acceptance.IncludeNilValuesTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("exclude")

      routes do
        base("/excludes")

        index(:read)
      end

      include_nil_values?(false)
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:foo, :string, public?: true)
      attribute(:bar, :string, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Include)
      resource(Exclude)
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

  describe "include index endpoint" do
    setup do
      include =
        Include
        |> Ash.Changeset.for_create(:create, %{foo: "foo"})
        |> Ash.create!()

      %{include: include}
    end

    test "returns a list of resources including nil values", %{include: include} do
      Domain
      |> get("/includes", status: 200)
      |> assert_data_equals([
        %{
          "attributes" => %{
            "foo" => "foo",
            "bar" => nil
          },
          "id" => include.id,
          "links" => %{},
          "meta" => %{},
          "relationships" => %{},
          "type" => "include"
        }
      ])
    end
  end

  describe "exclude index endpoint" do
    setup do
      exclude =
        Exclude
        |> Ash.Changeset.for_create(:create, %{foo: "foo"})
        |> Ash.create!()

      %{exclude: exclude}
    end

    test "returns a list of resources excluding nil values", %{exclude: exclude} do
      Domain
      |> get("/excludes", status: 200)
      |> assert_data_equals([
        %{
          "attributes" => %{
            "foo" => "foo"
          },
          "id" => exclude.id,
          "links" => %{},
          "meta" => %{},
          "relationships" => %{},
          "type" => "exclude"
        }
      ])
    end
  end
end
