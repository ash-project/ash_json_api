# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.UnionTest do
  use ExUnit.Case, async: true

  defmodule HeartRate do
    use Ash.Resource,
      domain: nil,
      data_layer: :embedded

    attributes do
      attribute(:bpm, :integer, public?: true, allow_nil?: false)
    end

    actions do
      defaults([:read, :destroy, create: :*, update: :*])
    end
  end

  defmodule BloodPressure do
    use Ash.Resource,
      domain: nil,
      data_layer: :embedded

    attributes do
      attribute(:systolic, :integer, public?: true, allow_nil?: false)
      attribute(:diastolic, :integer, public?: true, allow_nil?: false)
    end

    actions do
      defaults([:read, :destroy, create: :*, update: :*])
    end
  end

  defmodule MeasurementValue do
    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [
        types: [
          heart_rate: [
            type: HeartRate,
            tag: :type,
            tag_value: "heart_rate"
          ],
          blood_pressure: [
            type: BloodPressure,
            tag: :type,
            tag_value: "blood_pressure"
          ],
          note: [
            type: :string
          ]
        ]
      ]
  end

  defmodule Measurement do
    use Ash.Resource,
      domain: Test.Acceptance.UnionTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "measurement"

      routes do
        base "/measurements"
        get :read
        index :read
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:value, MeasurementValue, public?: true, allow_nil?: false)
      attribute(:values, {:array, MeasurementValue}, public?: true, default: [])
    end

    actions do
      default_accept([:value, :values])
      defaults([:read, :destroy, create: :*, update: :*])
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
      resource Measurement
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

  test "renders an embedded resource inside a union without needing Jason.Encoder" do
    m =
      Measurement
      |> Ash.Changeset.for_create(:create, %{
        value: %{type: "heart_rate", bpm: 72}
      })
      |> Ash.create!()

    response = Domain |> get("/measurements/#{m.id}", status: 200)
    attrs = response.resp_body["data"]["attributes"]

    assert attrs["value"] == %{"bpm" => 72}
  end

  test "renders a primitive value inside a union" do
    m =
      Measurement
      |> Ash.Changeset.for_create(:create, %{
        value: "feeling fine"
      })
      |> Ash.create!()

    response = Domain |> get("/measurements/#{m.id}", status: 200)
    attrs = response.resp_body["data"]["attributes"]

    assert attrs["value"] == "feeling fine"
  end

  test "renders an array of unions" do
    m =
      Measurement
      |> Ash.Changeset.for_create(:create, %{
        value: %{type: "heart_rate", bpm: 60},
        values: [
          %{type: "heart_rate", bpm: 80},
          %{type: "blood_pressure", systolic: 120, diastolic: 80}
        ]
      })
      |> Ash.create!()

    response = Domain |> get("/measurements/#{m.id}", status: 200)
    attrs = response.resp_body["data"]["attributes"]

    assert attrs["values"] == [
             %{"bpm" => 80},
             %{"systolic" => 120, "diastolic" => 80}
           ]
  end
end
