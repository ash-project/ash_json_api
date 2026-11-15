# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.PostWithoutBodyTest do
  @moduledoc """
  A post route whose action takes all of its input from the path should not
  document a request body. See https://github.com/ash-project/ash_json_api/issues/481
  """
  use ExUnit.Case, async: true

  defmodule WidgetRequest do
    use Ash.Resource,
      domain: Test.Acceptance.PostWithoutBodyTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type "widget_request"

      routes do
        base "/widgets"
        post :request_for_widget, route: "/:widget_id/requests"
        post :create, route: "/requests"
      end
    end

    actions do
      default_accept([:widget_id, :note])
      defaults([:read])

      create(:create)

      create :request_for_widget do
        accept([])
        argument(:widget_id, :integer, allow_nil?: false, public?: true)
        change(set_attribute(:widget_id, arg(:widget_id)))
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:widget_id, :integer, public?: true)
      attribute(:note, :string, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      authorize? false
    end

    resources do
      resource WidgetRequest
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

  describe "OpenAPI" do
    setup do
      %{spec: AshJsonApi.Controllers.OpenApi.spec(%{private: %{}}, domains: [Domain])}
    end

    test "a post route whose only input is a path param has no requestBody", %{spec: spec} do
      assert spec.paths["/widgets/{widget_id}/requests"].post.requestBody == nil
    end

    test "a post route that accepts attributes still has a requestBody", %{spec: spec} do
      assert %OpenApiSpex.RequestBody{} = spec.paths["/widgets/requests"].post.requestBody
    end
  end

  test "the route accepts a request with no body" do
    response =
      :post
      |> Plug.Test.conn("/widgets/7/requests", "")
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
      |> Router.call(Router.init([]))

    assert response.status == 201
    assert %{"data" => %{"attributes" => %{"widget_id" => 7}}} = Jason.decode!(response.resp_body)
  end

  test "the route accepts a request with an empty object body" do
    response = Domain |> post("/widgets/7/requests", %{}, status: 201)
    assert response.resp_body["data"]["attributes"]["widget_id"] == 7
  end
end
