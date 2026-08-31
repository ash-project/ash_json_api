# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.CrossDomainFieldsTest do
  use ExUnit.Case, async: true

  defmodule Contact do
    use Ash.Resource,
      domain: Test.Acceptance.CrossDomainFieldsTest.ContactsDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("contact")
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:first_name, :string, public?: true)
      attribute(:last_name, :string, public?: true)
      attribute(:phone, :string, public?: true)
    end

    calculations do
      calculate :full_name, :string, concat([:first_name, :last_name], arg(:separator)) do
        argument(:separator, :string, default: " ")
        public?(true)
      end
    end
  end

  defmodule User do
    use Ash.Resource,
      domain: Test.Acceptance.CrossDomainFieldsTest.UsersDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("user")
      includes([:contact])
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      belongs_to :contact, Contact do
        public?(true)
      end
    end
  end

  # Holds Contact only; never routed to. Deliberately no otp_app.
  defmodule ContactsDomain do
    use Ash.Domain, extensions: [AshJsonApi.Domain]

    resources do
      resource(Contact)
    end
  end

  # A decoy resource sharing the "contact" JSON:API type but without the
  # Contact fields, to prove the include graph wins over a flat domain scan.
  defmodule Decoy do
    use Ash.Resource,
      domain: Test.Acceptance.CrossDomainFieldsTest.DecoyDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("contact")
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:other_field, :string, public?: true)
    end
  end

  defmodule DecoyDomain do
    use Ash.Domain, extensions: [AshJsonApi.Domain]

    resources do
      resource(Decoy)
    end
  end

  # Route domain: deliberately NO otp_app, so the legacy
  # Spark.otp_app/:ash_domains fallback cannot resolve foreign types.
  defmodule UsersDomain do
    use Ash.Domain, extensions: [AshJsonApi.Domain]

    json_api do
      log_errors?(false)

      routes do
        base_route "/users", User do
          index(:read)
          get(:read)
        end
      end
    end

    resources do
      resource(User)
    end
  end

  defmodule Router do
    # Only the route domain: cross-domain types must resolve via the
    # request's include graph, not a scan of the router's domains.
    use AshJsonApi.Router, domain: UsersDomain
  end

  defmodule MultiDomainRouter do
    use AshJsonApi.Router, domains: [UsersDomain, ContactsDomain]
  end

  defmodule DecoyFirstRouter do
    # DecoyDomain precedes ContactsDomain, so a flat all_domains scan would
    # find Decoy first for the "contact" type.
    use AshJsonApi.Router, domains: [UsersDomain, DecoyDomain, ContactsDomain]
  end

  import AshJsonApi.Test

  setup do
    contact =
      Contact
      |> Ash.Changeset.for_create(:create, %{
        first_name: "Ada",
        last_name: "Lovelace",
        phone: "555-1234"
      })
      |> Ash.create!()

    user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "user1", contact_id: contact.id})
      |> Ash.create!()

    %{user: user, contact: contact}
  end

  test "include across domains works without sparse fieldsets", %{user: user} do
    response = get(UsersDomain, "/users/#{user.id}?include=contact", router: Router, status: 200)

    assert [%{"type" => "contact", "attributes" => attributes}] =
             response.resp_body["included"]

    assert Map.has_key?(attributes, "phone")
  end

  test "fields[contact] resolves the cross-domain included type and limits attributes",
       %{user: user} do
    response =
      get(
        UsersDomain,
        "/users/#{user.id}?include=contact&fields[contact]=first_name,last_name",
        router: Router,
        status: 200
      )

    assert [%{"type" => "contact", "attributes" => attributes}] =
             response.resp_body["included"]

    assert attributes == %{"first_name" => "Ada", "last_name" => "Lovelace"}
  end

  test "fields[contact] works on the index route too" do
    response =
      get(
        UsersDomain,
        "/users?include=contact&fields[contact]=first_name",
        router: Router,
        status: 200
      )

    assert [%{"type" => "contact", "attributes" => %{"first_name" => "Ada"} = attributes}] =
             response.resp_body["included"]

    refute Map.has_key?(attributes, "phone")
  end

  test "unknown type in fields still returns 400 invalid_type", %{user: user} do
    response =
      get(
        UsersDomain,
        "/users/#{user.id}?include=contact&fields[nonexistent]=foo",
        router: Router,
        status: 400
      )

    assert [error | _] = response.resp_body["errors"]
    assert error["code"] == "invalid_type"
  end

  test "field_inputs for a cross-domain included type are applied", %{user: user} do
    response =
      get(
        UsersDomain,
        "/users/#{user.id}?include=contact&fields[contact]=full_name&field_inputs[contact][full_name][separator]=%2C",
        router: Router,
        status: 200
      )

    assert [%{"type" => "contact", "attributes" => attributes}] =
             response.resp_body["included"]

    assert attributes == %{"full_name" => "Ada,Lovelace"}
  end

  test "fields[contact] resolves through the router's domains without an include",
       %{user: user} do
    response =
      get(
        UsersDomain,
        "/users/#{user.id}?fields[contact]=first_name",
        router: MultiDomainRouter,
        status: 200
      )

    assert response.resp_body["data"]["type"] == "user"
  end

  test "the include-graph destination wins over same-typed resources in other router domains",
       %{user: user} do
    # first_name exists on Contact but not on Decoy; resolving via the flat
    # domain scan would 400 with an invalid field error.
    response =
      get(
        UsersDomain,
        "/users/#{user.id}?include=contact&fields[contact]=first_name",
        router: DecoyFirstRouter,
        status: 200
      )

    assert [%{"type" => "contact", "attributes" => %{"first_name" => "Ada"}}] =
             response.resp_body["included"]
  end
end
