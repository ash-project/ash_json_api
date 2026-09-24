# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
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

    calculations do
      calculate :title_with_suffix, :string, expr(title <> ^arg(:suffix)) do
        public?(true)
        argument(:suffix, :string, allow_nil?: false)
      end
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
      assert errors != []

      error = Enum.find(errors, &(&1["code"] == "invalid_filter"))
      assert error, "Expected to find an 'invalid_filter' error"
      assert error["title"] == "InvalidFilter"
      assert error["detail"] == "Invalid filter"
      assert error["source"]["parameter"] == "filter"
      assert error["status"] == "400"
    end
  end

  describe "query parameters with the wrong shape" do
    defp error_for(path, code) do
      response = get(Domain, path, status: 400)
      error = Enum.find(response.resp_body["errors"], &(&1["code"] == code))
      assert error, "Expected a #{code} error, got: #{inspect(response.resp_body["errors"])}"
      assert error["status"] == "400"
      error
    end

    test "a list-valued include is invalid_includes" do
      error = error_for("/posts/with_filter_sort?include[]=comments", "invalid_includes")
      assert error["source"] == %{"parameter" => "include"}
    end

    test "a list-valued sparse fieldset is invalid_field" do
      error = error_for("/posts/with_filter_sort?fields[post][]=title", "invalid_field")
      assert error["detail"] == "Invalid fields for type post: expected a comma separated string"
      assert error["source"] == %{"parameter" => "fields[post]"}
    end

    test "a list-valued page is invalid_pagination" do
      error = error_for("/posts/with_filter_sort?page[]=1", "invalid_pagination")
      assert error["detail"] =~ "bracket notation"
    end

    test "a list-valued page[limit] is invalid_pagination" do
      error = error_for("/posts/with_filter_sort?page[limit][]=1", "invalid_pagination")
      assert error["detail"] == "Invalid pagination: page[limit] must be an integer"
      assert error["source"] == %{"parameter" => "page[limit]"}
    end

    test "a page[limit] that is not an integer is invalid_pagination" do
      error = error_for("/posts/with_filter_sort?page[limit]=abc", "invalid_pagination")
      assert error["detail"] == "Invalid pagination: page[limit] must be an integer"
      assert error["source"] == %{"parameter" => "page[limit]"}
    end

    test "a page[count] that is not a boolean is invalid_pagination" do
      error = error_for("/posts/with_filter_sort?page[count]=maybe", "invalid_pagination")
      assert error["detail"] == "Invalid pagination: page[count] must be true or false"
      assert error["source"] == %{"parameter" => "page[count]"}
    end

    test "list-valued field_inputs for a type is invalid_field" do
      error = error_for("/posts/with_filter_sort?field_inputs[post][]=x", "invalid_field")
      assert error["source"] == %{"parameter" => "field_inputs[post]"}
    end

    test "list-valued arguments for a calculation are invalid_field" do
      error =
        error_for(
          "/posts/with_filter_sort?field_inputs[post][title_with_suffix][]=x",
          "invalid_field"
        )

      assert error["source"] == %{"parameter" => "field_inputs[post][title_with_suffix]"}
    end
  end

  describe "filter errors raised while reading" do
    test "unknown filter field returns no_such_field with source parameter" do
      response =
        Domain
        |> get("/posts/with_filter_sort?filter[foo]=value", status: 400)

      assert [error] = response.resp_body["errors"]
      assert error["code"] == "no_such_field"
      assert error["title"] == "NoSuchField"
      assert error["detail"] == "no such field foo"
      assert error["meta"] == %{"field" => "foo"}
      assert error["source"] == %{"parameter" => "filter"}
      assert error["status"] == "400"
    end

    test "unknown filter predicate returns no_such_filter_predicate with source parameter" do
      response =
        Domain
        |> get("/posts/with_filter_sort?filter[title][foo]=value", status: 400)

      assert [error] = response.resp_body["errors"]
      assert error["code"] == "no_such_filter_predicate"
      assert error["title"] == "NoSuchFilterPredicate"
      assert error["detail"] == "no such filter predicate foo"
      assert error["meta"] == %{"key" => "foo"}
      assert error["source"] == %{"parameter" => "filter"}
      assert error["status"] == "400"
    end

    test "invalid filter value returns invalid_filter_value with source parameter" do
      response =
        Domain
        |> get("/posts/with_filter_sort?filter[title][in]=x", status: 400)

      assert [error] = response.resp_body["errors"]
      assert error["code"] == "invalid_filter_value"
      assert error["title"] == "InvalidFilterValue"
      assert String.starts_with?(error["detail"], "Invalid filter value")
      assert error["source"] == %{"parameter" => "filter"}
      assert error["status"] == "400"
    end
  end

  describe "InvalidFilterValue rendering" do
    test "the detail is built from the value and never includes the context" do
      # ash_postgres puts the whole Ecto query in `context` when a cast fails
      error =
        Ash.Error.Query.InvalidFilterValue.exception(
          value: "not-a-uuid",
          context: %{from: {"posts", TestPost}, wheres: [:do_not_render]}
        )

      rendered = AshJsonApi.ToJsonApiError.to_json_api_error(error)

      assert rendered.code == "invalid_filter_value"
      assert rendered.detail == ~s(Invalid filter value "not-a-uuid")
      refute rendered.detail =~ "do_not_render"
    end

    test "a plain-string message is appended to the detail" do
      error =
        Ash.Error.Query.InvalidFilterValue.exception(value: "x", message: "No matching types")

      assert AshJsonApi.ToJsonApiError.to_json_api_error(error).detail ==
               ~s(Invalid filter value "x": No matching types)
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
      assert errors != []

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
      assert errors != []

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

    test "RunStepError delegates to inner error with ToJsonApiError implementation" do
      inner_error = Ash.Error.Changes.InvalidChanges.exception(message: "bad input")

      run_step_error =
        Reactor.Error.Invalid.RunStepError.exception(
          error: inner_error,
          step: %Reactor.Step{name: :test_step}
        )

      result = AshJsonApi.Error.to_json_api_errors(nil, nil, run_step_error, :create)

      assert [json_error] = result
      assert json_error.code == "invalid"
      assert json_error.title == "Invalid"
      assert json_error.detail == "bad input"
    end

    test "RunStepError delegates to inner Ash wrapper error" do
      inner_error =
        Ash.Error.Changes.InvalidChanges.exception(message: "wrapped error")
        |> Ash.Error.to_error_class()

      run_step_error =
        Reactor.Error.Invalid.RunStepError.exception(
          error: inner_error,
          step: %Reactor.Step{name: :test_step}
        )

      result = AshJsonApi.Error.to_json_api_errors(nil, nil, run_step_error, :create)

      assert [json_error] = result
      assert json_error.code == "invalid"
      assert json_error.detail == "wrapped error"
    end

    @tag capture_log: true
    test "RunStepError falls back to generic error for unknown inner errors" do
      inner_error = RuntimeError.exception("something unexpected")

      run_step_error =
        Reactor.Error.Invalid.RunStepError.exception(
          error: inner_error,
          step: %Reactor.Step{name: :test_step}
        )

      result = AshJsonApi.Error.to_json_api_errors(Domain, TestPost, run_step_error, :create)

      assert [json_error] = result
      assert json_error.status_code == 500
      assert json_error.code == "something_went_wrong"
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
