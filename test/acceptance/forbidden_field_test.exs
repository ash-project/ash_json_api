# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.ForbiddenFieldTest do
  use ExUnit.Case, async: true

  defmodule AdminCheck do
    @moduledoc """
    A simple check that verifies if the actor has admin permissions.
    """
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(_), do: "actor is admin"

    @impl true
    def match?(actor, _context, _opts) do
      case actor do
        %{admin: true} -> true
        _ -> false
      end
    end
  end

  defmodule Dashboard do
    use Ash.Resource,
      otp_app: :ash_json_api,
      domain: Test.Acceptance.ForbiddenFieldTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource, Ash.Policy],
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private?(true)
    end

    json_api do
      type("dashboard")

      routes do
        base("/dashboards")
        index(:read)
        get(:read)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false, public?: true)
      attribute(:public_data, :string, public?: true)
      attribute(:pending_content_review_count, :integer, public?: true, default: 0)
      attribute(:pending_technical_review_count, :integer, public?: true, default: 0)
      attribute(:admin_notes, :string, public?: true)
    end

    # Policies to allow basic actions
    policies do
      policy always() do
        authorize_if(always())
      end
    end

    # Field policies to test forbidden field access
    field_policies do
      # These fields and calculations require admin permissions
      field_policy [
        :pending_content_review_count,
        :pending_technical_review_count,
        :admin_notes,
        :admin_calculation
      ] do
        authorize_if(AdminCheck)
      end

      # All other fields are accessible
      field_policy :* do
        authorize_if(always())
      end
    end

    calculations do
      # Admin-only calculation
      calculate :admin_calculation, :integer do
        public?(true)

        calculation(fn records, _context ->
          Enum.map(records, fn record ->
            record.pending_content_review_count + record.pending_technical_review_count
          end)
        end)

        description "Sum of pending reviews (admin-only)"
      end

      # Public calculation
      calculate :public_calculation, :integer do
        public?(true)

        calculation(fn records, _context ->
          Enum.map(records, fn record ->
            String.length(record.name || "") * 2
          end)
        end)

        description "Name length times 2 (public)"
      end
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        primary? true

        accept([
          :name,
          :public_data,
          :pending_content_review_count,
          :pending_technical_review_count,
          :admin_notes
        ])
      end
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? true
      log_errors? false
    end

    resources do
      resource(Dashboard)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    on_exit(fn ->
      try do
        Dashboard
        |> Ash.Query.for_read(:read, actor: %{admin: true})
        |> Ash.read!()
        |> Enum.each(&Ash.destroy!(&1, actor: %{admin: true}))
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "Field policies filter forbidden fields" do
    test "non-admin sees only public fields" do
      {:ok, dashboard} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Dashboard",
          public_data: "Public info",
          pending_content_review_count: 5,
          pending_technical_review_count: 3,
          admin_notes: "Secret notes"
        })
        |> Ash.create(actor: %{admin: true})

      response =
        Domain
        |> get("/dashboards/#{dashboard.id}", status: 200, actor: %{admin: false})

      attributes = response.resp_body["data"]["attributes"]

      # Public fields visible
      assert attributes["name"] == "Test Dashboard"
      assert attributes["public_data"] == "Public info"

      # Forbidden fields filtered out
      refute Map.has_key?(attributes, "pending_content_review_count")
      refute Map.has_key?(attributes, "pending_technical_review_count")
      refute Map.has_key?(attributes, "admin_notes")
    end

    test "admin sees all fields" do
      {:ok, dashboard} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Admin Dashboard",
          pending_content_review_count: 10,
          pending_technical_review_count: 7,
          admin_notes: "Admin-only notes"
        })
        |> Ash.create(actor: %{admin: true})

      response =
        Domain
        |> get("/dashboards/#{dashboard.id}", status: 200, actor: %{admin: true})

      attributes = response.resp_body["data"]["attributes"]

      # All fields visible
      assert attributes["name"] == "Admin Dashboard"
      assert attributes["pending_content_review_count"] == 10
      assert attributes["pending_technical_review_count"] == 7
      assert attributes["admin_notes"] == "Admin-only notes"
    end

    test "unauthenticated user cannot see forbidden fields" do
      {:ok, dashboard} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Public Dashboard",
          public_data: "Info",
          pending_content_review_count: 3,
          admin_notes: "Secret"
        })
        |> Ash.create(actor: %{admin: true})

      response =
        Domain
        |> get("/dashboards/#{dashboard.id}", status: 200)

      attributes = response.resp_body["data"]["attributes"]

      # Public fields visible
      assert attributes["name"] == "Public Dashboard"
      assert attributes["public_data"] == "Info"

      # Forbidden fields not visible
      refute Map.has_key?(attributes, "pending_content_review_count")
      refute Map.has_key?(attributes, "admin_notes")
    end

    test "forbidden fields filtered in list responses" do
      {:ok, _} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Dashboard 1",
          pending_content_review_count: 5,
          admin_notes: "Secret 1"
        })
        |> Ash.create(actor: %{admin: true})

      {:ok, _} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Dashboard 2",
          pending_content_review_count: 8,
          admin_notes: "Secret 2"
        })
        |> Ash.create(actor: %{admin: true})

      response =
        Domain
        |> get("/dashboards", status: 200, actor: %{admin: false})

      data = response.resp_body["data"]
      assert length(data) == 2

      for item <- data do
        attributes = item["attributes"]
        assert Map.has_key?(attributes, "name")
        refute Map.has_key?(attributes, "pending_content_review_count")
        refute Map.has_key?(attributes, "admin_notes")
      end
    end
  end

  describe "Calculations with field policies" do
    test "non-admin can access public calculation but not admin calculation" do
      {:ok, dashboard} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Test",
          pending_content_review_count: 5,
          pending_technical_review_count: 3
        })
        |> Ash.create(actor: %{admin: true})

      # Explicitly request both calculations - field policy should filter admin_calculation
      response =
        Domain
        |> get(
          "/dashboards/#{dashboard.id}?fields[dashboard]=name,public_calculation,admin_calculation",
          status: 200,
          actor: %{admin: false}
        )

      attributes = response.resp_body["data"]["attributes"]

      # Public calculation visible
      assert attributes["public_calculation"] == 8

      # Admin calculation NOT visible - filtered by field policy
      refute Map.has_key?(attributes, "admin_calculation")
    end

    test "admin can access both public and admin calculations" do
      {:ok, dashboard} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Admin",
          pending_content_review_count: 4,
          pending_technical_review_count: 6
        })
        |> Ash.create(actor: %{admin: true})

      # Explicitly request both calculations - admin should see both
      response =
        Domain
        |> get(
          "/dashboards/#{dashboard.id}?fields[dashboard]=name,public_calculation,admin_calculation",
          status: 200,
          actor: %{admin: true}
        )

      attributes = response.resp_body["data"]["attributes"]

      # Both calculations visible
      assert attributes["public_calculation"] == 10
      assert attributes["admin_calculation"] == 10
    end

    test "unauthenticated user can access public calculation" do
      {:ok, dashboard} =
        Dashboard
        |> Ash.Changeset.for_create(:create, %{
          name: "Public",
          pending_content_review_count: 2
        })
        |> Ash.create(actor: %{admin: true})

      # Explicitly request both calculations - field policy should filter admin_calculation
      response =
        Domain
        |> get(
          "/dashboards/#{dashboard.id}?fields[dashboard]=name,public_calculation,admin_calculation",
          status: 200
        )

      attributes = response.resp_body["data"]["attributes"]

      # Public calculation visible
      assert attributes["public_calculation"] == 12

      # Admin calculation NOT visible - filtered by field policy
      refute Map.has_key?(attributes, "admin_calculation")
    end
  end

  describe "Protocol implementation for ForbiddenField" do
    test "converts ForbiddenField to 403 JSON:API error" do
      error =
        Ash.Error.Forbidden.ForbiddenField.exception(field: :admin_notes, resource: Dashboard)

      json_error = AshJsonApi.ToJsonApiError.to_json_api_error(error)

      assert json_error.status_code == 403
      assert json_error.code == "forbidden"
      assert json_error.title == "Forbidden"
      assert is_binary(json_error.id)
    end

    test "handles nested ForbiddenField in Forbidden error" do
      forbidden_field =
        Ash.Error.Forbidden.ForbiddenField.exception(
          field: :pending_content_review_count,
          resource: Dashboard
        )

      forbidden_error = Ash.Error.Forbidden.exception(errors: [forbidden_field])
      result = AshJsonApi.Error.to_json_api_errors(Domain, Dashboard, forbidden_error, :read)

      assert is_list(result)
      assert result != []

      json_error = hd(result)
      assert json_error.status_code == 403
      assert json_error.code == "forbidden"
    end

    test "class_to_status returns correct HTTP codes" do
      assert AshJsonApi.Error.class_to_status(:forbidden) == 403
      assert AshJsonApi.Error.class_to_status(:invalid) == 400
      assert AshJsonApi.Error.class_to_status(:unknown) == 500
    end
  end
end
