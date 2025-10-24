# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.ErrorValidationTest do
  use ExUnit.Case, async: true

  defmodule TestPost do
    use Ash.Resource,
      domain: Test.Acceptance.ErrorValidationTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "post"

      routes do
        base "/posts"

        # Route with filtering/sorting disabled for testing InvalidFilter/InvalidSort
        index :read, derive_filter?: false, derive_sort?: false, route: "/no_filter_sort"

        # Route with filtering/sorting enabled for testing invalid field names
        index :read, derive_filter?: true, derive_sort?: true, route: "/with_filter_sort"
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
      attribute(:content, :string, public?: true)
    end

    actions do
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
      resource TestPost
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
        TestPost
        |> Ash.Query.for_read(:read)
        |> Ash.read!()
        |> Enum.each(&Ash.destroy!(&1))
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "InvalidFilter errors" do
    test "returns proper error when filter is invalid type on derive_filter?: true route" do
      # This triggers the error: derive_filter?: true but filter is array (not string or map)
      response =
        Domain
        |> get("/posts/with_filter_sort?filter[]=invalid", status: 400)

      errors = response.resp_body["errors"]
      assert is_list(errors)
      assert length(errors) > 0

      error = Enum.find(errors, &(&1["code"] == "invalid_filter"))
      assert error, "Expected to find an 'invalid_filter' error"
      assert error["title"] == "InvalidFilter"
      assert error["detail"] == "Invalid filter"
      assert error["source"]["parameter"] == "filter"
      assert error["status"] == "400"
    end
  end

  describe "InvalidSort errors" do
    test "returns proper error when sort is invalid type on derive_sort?: true route" do
      # This triggers the error: derive_sort?: true but sort is array (not string)
      response =
        Domain
        |> get("/posts/with_filter_sort?sort[]=title", status: 400)

      errors = response.resp_body["errors"]
      assert is_list(errors)
      assert length(errors) > 0

      error = Enum.find(errors, &(&1["code"] == "invalid_sort"))
      assert error, "Expected to find an 'invalid_sort' error"
      assert error["title"] == "InvalidSort"
      assert String.contains?(error["detail"], "Invalid sort")
      assert error["source"]["parameter"] == "sort"
      assert error["status"] == "400"
    end

    test "returns proper error for invalid field in sort string" do
      response =
        Domain
        |> get("/posts/with_filter_sort?sort=invalid_field_name", status: 400)

      errors = response.resp_body["errors"]
      assert is_list(errors)
      assert length(errors) > 0

      error = Enum.find(errors, &(&1["code"] == "invalid_sort"))
      assert error, "Expected to find an 'invalid_sort' error"
      assert error["title"] == "InvalidSort"
      assert String.contains?(error["detail"], "Invalid sort field: invalid_field_name")
      assert error["source"]["parameter"] == "sort"
      assert error["status"] == "400"
    end
  end

  describe "Direct function tests for complex scenarios" do
    test "ConflictingParams error creation and JSON:API conversion" do
      # Test the error struct directly
      error = AshJsonApi.Error.ConflictingParams.exception(conflicting_keys: ["name", "id"])

      # Test ToJsonApiError protocol
      json_error = AshJsonApi.ToJsonApiError.to_json_api_error(error)

      assert json_error.status_code == 400
      assert json_error.code == "invalid_query"
      assert json_error.title == "InvalidQuery"
      assert json_error.detail == "conflict path and query params"
      assert is_binary(json_error.id)
    end

    test "MissingSchema error creation and JSON:API conversion" do
      error = AshJsonApi.Error.MissingSchema.exception([])

      json_error = AshJsonApi.ToJsonApiError.to_json_api_error(error)

      assert json_error.status_code == 400
      assert json_error.code == "missing_schema"
      assert json_error.title == "MissingSchema"
      assert json_error.detail == "No schema found for validation"
      assert is_binary(json_error.id)
    end

    test "InvalidPathParam error creation and JSON:API conversion" do
      error = AshJsonApi.Error.InvalidPathParam.exception(parameter: "id", url: "/test/url")

      json_error = AshJsonApi.ToJsonApiError.to_json_api_error(error)

      assert json_error.status_code == 400
      assert json_error.code == "invalid_path_param"
      assert json_error.title == "InvalidPathParam"

      assert String.contains?(
               json_error.detail,
               "id path parameter not present in route: /test/url"
             )

      assert is_binary(json_error.id)
    end

    test "UnknownError creation and JSON:API conversion" do
      error = AshJsonApi.Error.UnknownError.exception(message: "Something unexpected happened")

      json_error = AshJsonApi.ToJsonApiError.to_json_api_error(error)

      assert json_error.status_code == 500
      assert json_error.code == "unknown_error"
      assert json_error.title == "UnknownError"
      assert json_error.detail == "Something unexpected happened"
      assert is_binary(json_error.id)
    end

    test "Binary error fallback uses UnknownError" do
      # Test the binary error handler directly
      domain = nil
      resource = nil
      binary_error = "some unexpected string error"
      operation_type = :read

      result = AshJsonApi.Error.to_json_api_errors(domain, resource, binary_error, operation_type)

      assert is_list(result)
      assert length(result) == 1

      [json_error] = result
      assert json_error.status_code == 500
      assert json_error.code == "unknown_error"
      assert json_error.title == "UnknownError"
      assert json_error.detail == "some unexpected string error"
      assert is_binary(json_error.id)
    end
  end
end
