# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.ErrorHandlerTest do
  use ExUnit.Case, async: true

  defmodule ErrorHandler do
    def handle_error(error, _context) do
      %{error | detail: "transformed: #{error.detail}"}
    end
  end

  defmodule ContextCapturingHandler do
    def handle_error(error, context) do
      %{error | meta: Map.put(error.meta || %{}, :captured_domain, context.domain)}
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.ErrorHandlerTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "post"

      routes do
        base "/posts"
        index :read
        get :read
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
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
      error_handler {ErrorHandler, :handle_error, []}
    end

    resources do
      resource Post
    end
  end

  defmodule PlainPost do
    use Ash.Resource,
      domain: Test.Acceptance.ErrorHandlerTest.PlainDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "plain_post"

      routes do
        base "/plain_posts"
        get :read
        post :create
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, allow_nil?: false, public?: true)
    end

    actions do
      defaults([:read, :create])
    end
  end

  defmodule PlainDomain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? false
      log_errors? false
    end

    resources do
      resource PlainPost
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  defmodule PlainRouter do
    use AshJsonApi.Router, domain: PlainDomain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])
    Application.put_env(:ash_json_api, PlainDomain, json_api: [test_router: PlainRouter])
    :ok
  end

  describe "error_handler domain option" do
    test "transforms errors via the handler on HTTP requests" do
      response = Domain |> get("/posts/nonexistent-id", status: 404)

      [error] = response.resp_body["errors"]
      assert String.starts_with?(error["detail"], "transformed: ")
    end

    test "handler is called for validation errors on HTTP requests" do
      response =
        Domain
        |> post("/posts", %{data: %{type: "post", attributes: %{}}}, status: 400)

      errors = response.resp_body["errors"]
      assert errors != []
      assert Enum.all?(errors, fn e -> String.starts_with?(e["detail"], "transformed: ") end)
    end

    test "handler is applied to already-converted AshJsonApi.Error structs" do
      pre_converted = %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "some_error",
        title: "SomeError",
        detail: "original detail",
        meta: %{}
      }

      [result] = AshJsonApi.Error.to_json_api_errors(Domain, Post, pre_converted, :read)
      assert result.detail == "transformed: original detail"
    end

    test "handler receives domain in context" do
      error = Ash.Error.Changes.InvalidChanges.exception(message: "bad input")

      [result] =
        AshJsonApi.Error.to_json_api_errors(
          Test.Acceptance.ErrorHandlerTest.DomainWithContextHandler,
          Post,
          error,
          :create
        )

      assert result.meta[:captured_domain] == Test.Acceptance.ErrorHandlerTest.DomainWithContextHandler
    end

    test "without error_handler, errors pass through unchanged" do
      error = Ash.Error.Changes.InvalidChanges.exception(message: "bad input")

      [result] = AshJsonApi.Error.to_json_api_errors(PlainDomain, PlainPost, error, :create)
      assert result.detail == "bad input"
      refute String.starts_with?(result.detail, "transformed: ")
    end

    test "without error_handler on HTTP request, errors are not transformed" do
      response =
        PlainDomain
        |> post("/plain_posts", %{data: %{type: "plain_post", attributes: %{}}}, status: 400)

      errors = response.resp_body["errors"]
      assert errors != []
      assert Enum.all?(errors, fn e -> not String.starts_with?(e["detail"], "transformed: ") end)
    end
  end

  defmodule DomainWithContextHandler do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? false
      log_errors? false
      error_handler {ContextCapturingHandler, :handle_error, []}
    end

    resources do
      resource Post
    end
  end
end
