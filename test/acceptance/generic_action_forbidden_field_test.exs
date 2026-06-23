# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.GenericActionForbiddenFieldTest do
  use ExUnit.Case, async: true

  defmodule AdminCheck do
    @moduledoc false
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

  defmodule Report do
    use Ash.Resource,
      otp_app: :ash_json_api,
      domain: Test.Acceptance.GenericActionForbiddenFieldTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource, Ash.Policy],
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private?(true)
    end

    json_api do
      type("report")

      routes do
        base("/reports")
        get(:read)

        # Generic actions that return the resource itself. These exercise
        # the run_action -> load_action_data path so that field policies
        # scrub fields the actor isn't allowed to see.
        route(:get, "/latest", :latest_report)
        route(:post, "/snapshot", :snapshot_report)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
      attribute(:public_summary, :string, public?: true)
      attribute(:internal_metrics, :integer, public?: true, default: 0)
      attribute(:admin_notes, :string, public?: true)
    end

    policies do
      policy always() do
        authorize_if(always())
      end
    end

    field_policies do
      field_policy [:internal_metrics, :admin_notes] do
        authorize_if(AdminCheck)
      end

      field_policy :* do
        authorize_if(always())
      end
    end

    actions do
      defaults([:read])

      create :create do
        primary? true
        accept([:title, :public_summary, :internal_metrics, :admin_notes])
      end

      action :latest_report, :struct do
        constraints(instance_of: __MODULE__)

        run(fn _input, _ctx ->
          case Report
               |> Ash.Query.sort(title: :asc)
               |> Ash.Query.limit(1)
               |> Ash.read(authorize?: false) do
            {:ok, [report]} -> {:ok, report}
            {:ok, []} -> {:error, "no report"}
            {:error, error} -> {:error, error}
          end
        end)
      end

      action :snapshot_report, :struct do
        constraints(instance_of: __MODULE__)

        argument(:title, :string, allow_nil?: false)
        argument(:public_summary, :string, allow_nil?: true)
        argument(:internal_metrics, :integer, allow_nil?: true)
        argument(:admin_notes, :string, allow_nil?: true)

        run(fn input, _ctx ->
          Report
          |> Ash.Changeset.for_create(:create, input.arguments)
          |> Ash.create(authorize?: false)
        end)
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
      resource(Report)
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
        Report
        |> Ash.Query.for_read(:read, actor: %{admin: true})
        |> Ash.read!()
        |> Enum.each(&Ash.destroy!(&1, actor: %{admin: true}))
      rescue
        _ -> :ok
      end
    end)

    {:ok, report} =
      Report
      |> Ash.Changeset.for_create(:create, %{
        title: "Q1",
        public_summary: "Visible to everyone",
        internal_metrics: 42,
        admin_notes: "secret"
      })
      |> Ash.create(actor: %{admin: true})

    {:ok, report: report}
  end

  describe "GET generic action route returning resource record" do
    test "non-admin caller does not see policy-forbidden fields" do
      response = get(Domain, "/reports/latest", status: 200, actor: %{admin: false})

      attrs = response.resp_body

      assert attrs["title"] == "Q1"
      assert attrs["public_summary"] == "Visible to everyone"

      refute Map.has_key?(attrs, "internal_metrics")
      refute Map.has_key?(attrs, "admin_notes")
    end

    test "admin sees policy-protected fields" do
      response = get(Domain, "/reports/latest", status: 200, actor: %{admin: true})

      attrs = response.resp_body

      assert attrs["title"] == "Q1"
      assert attrs["public_summary"] == "Visible to everyone"
      assert attrs["internal_metrics"] == 42
      assert attrs["admin_notes"] == "secret"
    end
  end

  describe "POST generic action route returning resource record" do
    test "non-admin caller does not see policy-forbidden fields on the returned snapshot" do
      response =
        post(
          Domain,
          "/reports/snapshot",
          %{
            data: %{
              title: "Q2",
              public_summary: "Posted summary",
              internal_metrics: 99,
              admin_notes: "post-secret"
            }
          },
          status: 201,
          actor: %{admin: false}
        )

      attrs = response.resp_body

      assert attrs["title"] == "Q2"
      assert attrs["public_summary"] == "Posted summary"

      refute Map.has_key?(attrs, "internal_metrics")
      refute Map.has_key?(attrs, "admin_notes")
    end

    test "admin sees policy-protected fields on the returned snapshot" do
      response =
        post(
          Domain,
          "/reports/snapshot",
          %{
            data: %{
              title: "Q3",
              public_summary: "Admin summary",
              internal_metrics: 77,
              admin_notes: "admin-secret"
            }
          },
          status: 201,
          actor: %{admin: true}
        )

      attrs = response.resp_body

      assert attrs["title"] == "Q3"
      assert attrs["internal_metrics"] == 77
      assert attrs["admin_notes"] == "admin-secret"
    end
  end
end
