# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.RequireTypeOnCreateTest do
  @moduledoc """
  Tests for JSON:API type-on-create compliance (issue #164).
  When require_type_on_create? is true, POST create requests must include `type` in the data object.
  """
  use ExUnit.Case, async: true

  # Resource used by domain with require_type_on_create? false (default)
  defmodule DefaultArticle do
    use Ash.Resource,
      domain: Test.Acceptance.RequireTypeOnCreateTest.DefaultDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "article"

      routes do
        base "/articles"
        index :read
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept [:title]
      end
    end
  end

  # Resource used by domain with require_type_on_create? true
  defmodule StrictArticle do
    use Ash.Resource,
      domain: Test.Acceptance.RequireTypeOnCreateTest.StrictDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "article"

      routes do
        base "/articles"
        index :read
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept [:title]
      end
    end
  end

  defmodule DefaultDomain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? false
      log_errors? false
      # require_type_on_create? not set -> defaults to false (backwards compatible)
    end

    resources do
      resource DefaultArticle
    end
  end

  defmodule StrictDomain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? false
      log_errors? false
      require_type_on_create? true
    end

    resources do
      resource StrictArticle
    end
  end

  defmodule DefaultRouter do
    use AshJsonApi.Router, domain: DefaultDomain
  end

  defmodule StrictRouter do
    use AshJsonApi.Router, domain: StrictDomain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, DefaultDomain, json_api: [test_router: DefaultRouter])
    Application.put_env(:ash_json_api, StrictDomain, json_api: [test_router: StrictRouter])

    on_exit(fn ->
      for {domain, resource} <- [{DefaultDomain, DefaultArticle}, {StrictDomain, StrictArticle}] do
        try do
          resource
          |> Ash.Query.for_read(:read)
          |> Ash.read!(domain: domain)
          |> Enum.each(&Ash.destroy!(&1, domain: domain))
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end

  describe "require_type_on_create? false (default domain)" do
    test "POST with data but no type key still processes (backwards compatible)" do
      # When opt-in is false, omitting type must not trigger missing_type error.
      # Request may still fail on schema/validation; we only assert we don't get missing_type.
      response =
        DefaultDomain
        |> post("/articles", %{
          data: %{
            attributes: %{title: "No type here"}
          }
        })

      # Either success or a different error (e.g. invalid_body from schema), never missing_type
      if response.status == 400 do
        errors = response.resp_body["errors"] || []
        codes = Enum.map(errors, & &1["code"])
        refute "missing_type" in codes, "Expected no missing_type when require_type_on_create? is false"
      end
    end

    test "POST with data and type succeeds" do
      DefaultDomain
      |> post("/articles", %{
        data: %{
          type: "article",
          attributes: %{title: "With type"}
        }
      }, status: 201)
      |> assert_attribute_equals("title", "With type")
    end
  end

  describe "require_type_on_create? true (strict domain)" do
    test "POST with data and valid type succeeds" do
      StrictDomain
      |> post("/articles", %{
        data: %{
          type: "article",
          attributes: %{title: "Valid"}
        }
      }, status: 201)
      |> assert_attribute_equals("title", "Valid")
    end

    test "POST with data but no type key returns 400 with missing_type error" do
      response =
        StrictDomain
        |> post("/articles", %{
          data: %{
            attributes: %{title: "Missing type"}
          }
        }, status: 400)

      errors = response.resp_body["errors"]
      assert is_list(errors)
      assert length(errors) >= 1

      error = Enum.find(errors, &(&1["code"] == "missing_type"))
      assert error, "Expected one error with code missing_type, got: #{inspect(Enum.map(errors, & &1["code"]))}"
      assert error["title"] == "Invalid resource object"
      assert error["detail"] == "The resource object MUST contain at least a type member."
      assert error["source"]["pointer"] == "/data"
      assert error["status"] == "400"
    end

    test "POST with data and empty string type returns 400 with missing_type error" do
      response =
        StrictDomain
        |> post("/articles", %{
          data: %{
            type: "",
            attributes: %{title: "Empty type"}
          }
        }, status: 400)

      errors = response.resp_body["errors"]
      assert is_list(errors)

      error = Enum.find(errors, &(&1["code"] == "missing_type"))
      assert error, "Expected missing_type when type is empty string"
      assert error["source"]["pointer"] == "/data"
    end

    test "POST with body without data key does not trigger missing_type" do
      # When there is no "data" key, our validation does not run (we only check when data is a map).
      # The request may fail for other reasons (e.g. invalid_body from schema).
      response =
        StrictDomain
        |> post("/articles", %{meta: %{}}, status: 400)

      errors = response.resp_body["errors"] || []
      codes = Enum.map(errors, & &1["code"])
      # We do not add missing_type when there is no data object
      refute "missing_type" in codes
    end

    test "POST with data null does not trigger missing_type" do
      # data: null - our clause requires is_map(data), so we pass through
      response =
        StrictDomain
        |> post("/articles", %{data: nil}, status: 400)

      errors = response.resp_body["errors"] || []
      codes = Enum.map(errors, & &1["code"])
      refute "missing_type" in codes
    end

    test "POST with data as empty map and no type returns 400 with missing_type" do
      response =
        StrictDomain
        |> post("/articles", %{data: %{}}, status: 400)

      errors = response.resp_body["errors"]
      error = Enum.find(errors, &(&1["code"] == "missing_type"))
      assert error
      assert error["source"]["pointer"] == "/data"
    end

    test "non-POST requests are not affected by require_type_on_create?" do
      # Create one article first so we can index
      StrictDomain
      |> post("/articles", %{
        data: %{type: "article", attributes: %{title: "One"}}
      }, status: 201)

      # GET index does not validate body type
      response = StrictDomain |> get("/articles")
      assert response.status == 200
      assert is_list(response.resp_body["data"])
    end
  end

  describe "MissingTypeOnCreate error module" do
    test "exception has correct message" do
      error = AshJsonApi.Error.MissingTypeOnCreate.exception([])
      assert Exception.message(error) == "The resource object MUST contain at least a type member."
    end

    test "ToJsonApiError returns 400 with code, title, detail, source_pointer" do
      error = AshJsonApi.Error.MissingTypeOnCreate.exception([])
      json_error = AshJsonApi.ToJsonApiError.to_json_api_error(error)

      assert json_error.status_code == 400
      assert json_error.code == "missing_type"
      assert json_error.title == "Invalid resource object"
      assert json_error.detail == "The resource object MUST contain at least a type member."
      assert json_error.source_pointer == "/data"
      assert is_binary(json_error.id)
    end
  end

  describe "Domain.Info.require_type_on_create?" do
    test "returns false when option not set" do
      assert AshJsonApi.Domain.Info.require_type_on_create?(DefaultDomain) == false
    end

    test "returns true when option is true" do
      assert AshJsonApi.Domain.Info.require_type_on_create?(StrictDomain) == true
    end
  end
end
