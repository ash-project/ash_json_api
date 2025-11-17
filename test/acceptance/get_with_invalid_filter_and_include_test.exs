# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.GetWithInvalidFilterAndIncludeTest do
  use ExUnit.Case, async: true

  @moduledoc """
  This test module verifies the fix for a bug where GET /:id routes with includes
  would crash with a KeyError instead of returning a JSON:API error document.

  The bug occurred when fetch_record_from_path/3 encountered an invalid filter
  and returned {:error, Request.add_error(...)} instead of just Request.add_error(...).
  This caused chain/3 to receive a tuple instead of a Request struct, leading to
  a KeyError when trying to access request.errors.
  """

  defmodule Membership do
    use Ash.Resource,
      domain: Test.Acceptance.GetWithInvalidFilterAndIncludeTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "membership"
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:role, :string, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    relationships do
      belongs_to(:user, Test.Acceptance.GetWithInvalidFilterAndIncludeTest.User, public?: true)
    end
  end

  defmodule User do
    use Ash.Resource,
      domain: Test.Acceptance.GetWithInvalidFilterAndIncludeTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "user"

      routes do
        base "/users"
        get(:read)
        index(:read)
      end

      includes memberships: []
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    relationships do
      has_many(:memberships, Membership, public?: true, destination_attribute: :user_id)
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
      resource User
      resource Membership
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
        User
        |> Ash.Query.for_read(:read)
        |> Ash.read!()
        |> Enum.each(&Ash.destroy!(&1))
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "GET /:id with invalid filter and includes" do
    test "returns JSON:API error document instead of crashing with KeyError" do
      # Create a user with memberships
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "John Doe", email: "john@example.com"})
        |> Ash.create!()

      _membership =
        Membership
        |> Ash.Changeset.for_create(:create, %{role: "admin", user_id: user.id})
        |> Ash.create!()

      # This request triggers a filter error in fetch_record_from_path when the ID
      # format is invalid. The bug would cause a KeyError because fetch_record_from_path
      # returned {:error, request} instead of just request, and chain/3 would try to
      # access request.errors on the tuple.
      #
      # With the fix, this returns a proper 404 error document
      response =
        Domain
        |> get("/users/invalid-id-format?include=memberships", status: 404)

      # Verify we get a proper JSON:API error response, not a crash
      assert is_map(response.resp_body)
      assert Map.has_key?(response.resp_body, "errors")
      errors = response.resp_body["errors"]
      assert is_list(errors)
      assert length(errors) > 0

      # Verify the error has proper JSON:API structure
      error = hd(errors)
      assert is_map(error)
      assert Map.has_key?(error, "code")
      assert Map.has_key?(error, "title")
      assert Map.has_key?(error, "detail")
      assert Map.has_key?(error, "status")

      # The key point: we got a proper error response (404), not a 500 crash
      assert error["status"] == "404"
      assert error["code"] == "not_found"
    end

    test "returns JSON:API error for non-existent ID with includes" do
      # Use a valid UUID format but non-existent ID
      non_existent_id = Ash.UUID.generate()

      response =
        Domain
        |> get("/users/#{non_existent_id}?include=memberships", status: 404)

      # Verify we get a proper 404 JSON:API error response
      assert is_map(response.resp_body)
      assert Map.has_key?(response.resp_body, "errors")
      errors = response.resp_body["errors"]
      assert is_list(errors)
      assert length(errors) > 0

      error = hd(errors)
      assert error["status"] == "404"
      assert error["code"] == "not_found"
    end

    test "successfully returns data with valid ID and includes" do
      # Create a user with memberships
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Jane Smith", email: "jane@example.com"})
        |> Ash.create!()

      membership =
        Membership
        |> Ash.Changeset.for_create(:create, %{role: "member", user_id: user.id})
        |> Ash.create!()

      # This should work correctly
      response =
        Domain
        |> get("/users/#{user.id}?include=memberships", status: 200)

      # Verify successful response
      assert is_map(response.resp_body)
      assert Map.has_key?(response.resp_body, "data")
      data = response.resp_body["data"]
      assert data["id"] == user.id
      assert data["type"] == "user"

      # Verify included memberships
      assert Map.has_key?(response.resp_body, "included")
      included = response.resp_body["included"]
      assert is_list(included)
      assert length(included) > 0

      membership_data = Enum.find(included, &(&1["type"] == "membership"))
      assert membership_data
      assert membership_data["id"] == membership.id
      assert membership_data["attributes"]["role"] == "member"
    end
  end

  describe "GET /:id with complex scenarios" do
    test "handles non-existent ID with complex includes gracefully" do
      # Use a non-existent ID to trigger the error path in fetch_record_from_path
      # This exercises the code path where the lookup fails and we need to add an error
      non_existent_id = Ash.UUID.generate()

      # Before the fix, this would crash with KeyError when chain/3 tried to access
      # request.errors on {:error, request}. After the fix, it returns proper 404.
      response =
        Domain
        |> get("/users/#{non_existent_id}?include=memberships", status: 404)

      # Should return error document, not crash
      assert is_map(response.resp_body)
      assert Map.has_key?(response.resp_body, "errors")
      errors = response.resp_body["errors"]
      assert is_list(errors)
      assert length(errors) > 0

      error = hd(errors)
      assert error["status"] == "404"
      assert error["code"] == "not_found"
    end
  end
end
