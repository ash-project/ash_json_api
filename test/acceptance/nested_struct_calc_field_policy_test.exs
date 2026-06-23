# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.NestedStructCalcFieldPolicyTest do
  @moduledoc """
  When a JSON:API response includes a calculation that returns a
  `:struct` of a resource with its own field policies, the read
  pipeline's `load_through_attributes` step now routes every loadable
  calc value through `Ash.Type.load`, even when no nested load was
  requested. That hits `Ash.Type.Struct.load/4`, which applies the
  nested resource's field policies (via `apply_field_level_auth/3` for
  already-populated attributes), so forbidden fields are scrubbed
  before the serializer ever sees them.
  """
  use ExUnit.Case, async: true

  defmodule AdminCheck do
    @moduledoc false
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(_), do: "actor is admin"

    @impl true
    def match?(%{admin: true}, _, _), do: true
    def match?(_, _, _), do: false
  end

  defmodule NestedDoc do
    @moduledoc false
    use Ash.Resource,
      otp_app: :ash_json_api,
      domain: Test.Acceptance.NestedStructCalcFieldPolicyTest.Domain,
      data_layer: :embedded,
      extensions: [AshJsonApi.Resource, Ash.Policy],
      authorizers: [Ash.Policy.Authorizer]

    attributes do
      uuid_primary_key :id, writable?: true
      attribute :public_note, :string, public?: true
      attribute :admin_note, :string, public?: true
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end

    field_policies do
      field_policy :admin_note do
        authorize_if AdminCheck
      end

      field_policy :* do
        authorize_if always()
      end
    end

    actions do
      defaults [:read]

      create :create do
        primary? true
        accept [:public_note, :admin_note]
      end
    end
  end

  defmodule Container do
    @moduledoc false
    use Ash.Resource,
      otp_app: :ash_json_api,
      domain: Test.Acceptance.NestedStructCalcFieldPolicyTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource, Ash.Policy],
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private?(true)
    end

    json_api do
      type "container"

      routes do
        base("/containers")
        get(:read)
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true
    end

    calculations do
      calculate :nested_doc, :struct do
        public? true
        constraints instance_of: NestedDoc

        calculation fn records, _context ->
          Enum.map(records, fn _record ->
            %NestedDoc{
              id: Ash.UUID.generate(),
              public_note: "fine to see",
              admin_note: "should be hidden from non-admins"
            }
          end)
        end
      end
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end

    actions do
      defaults [:read]

      create :create do
        primary? true
        accept [:name]
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
      resource(Container)
      resource(NestedDoc)
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
        Container
        |> Ash.Query.for_read(:read, actor: %{admin: true})
        |> Ash.read!()
        |> Enum.each(&Ash.destroy!(&1, actor: %{admin: true}))
      rescue
        _ -> :ok
      end
    end)

    {:ok, container} =
      Container
      |> Ash.Changeset.for_create(:create, %{name: "C1"})
      |> Ash.create(actor: %{admin: true})

    {:ok, container: container}
  end

  describe "calc returning :struct instance_of: NestedDoc (field policies on NestedDoc)" do
    test "non-admin: nested_doc.admin_note is scrubbed", %{container: container} do
      response =
        Domain
        |> get("/containers/#{container.id}?fields[container]=nested_doc",
          status: 200,
          actor: %{admin: false}
        )

      attrs = response.resp_body["data"]["attributes"]
      nested = attrs["nested_doc"]

      assert is_map(nested), "expected nested_doc to be serialized as an object"
      assert nested["public_note"] == "fine to see"

      # NestedDoc's field policy hides admin_note from non-admins. The
      # serializer skips fields whose value is %Ash.ForbiddenField{},
      # so the key is absent (or nil) from the response payload.
      assert is_nil(nested["admin_note"])
    end

    test "admin: nested_doc.admin_note is visible", %{container: container} do
      response =
        Domain
        |> get("/containers/#{container.id}?fields[container]=nested_doc",
          status: 200,
          actor: %{admin: true}
        )

      attrs = response.resp_body["data"]["attributes"]
      nested = attrs["nested_doc"]

      assert nested["public_note"] == "fine to see"
      assert nested["admin_note"] == "should be hidden from non-admins"
    end
  end
end
