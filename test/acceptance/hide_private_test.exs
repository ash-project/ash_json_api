# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.HidePrivateTest do
  use ExUnit.Case, async: true

  alias OpenApiSpex.{OpenApi, Operation, RequestBody}

  # A resource with both public and private attributes in the accept list,
  # exposed via two routes: one with hide_private?: true and one without.
  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.HidePrivateTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("post")

      routes do
        base("/posts")

        post(:create,
          name: "createPost",
          hide_private?: true
        )

        post(:create,
          name: "createPostExposed",
          route: "/exposed",
          hide_private?: false
        )

        patch(:update,
          name: "updatePost",
          hide_private?: true
        )

        patch(:update,
          name: "updatePostExposed",
          route: "/:id/exposed",
          hide_private?: false
        )
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :destroy])

      create :create do
        primary? true
        accept([:name, :internal_notes])
      end

      update :update do
        primary? true
        accept([:name, :internal_notes])
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)

      attribute(:name, :string,
        allow_nil?: false,
        public?: true
      )

      attribute(:internal_notes, :string,
        allow_nil?: true,
        public?: false
      )
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Post)
    end
  end

  setup do
    api_spec =
      AshJsonApi.Controllers.OpenApi.spec(%{private: %{}}, domains: [Domain])

    %{open_api_spec: api_spec}
  end

  describe "hide_private?: true on create route" do
    test "excludes private attributes from request body schema", %{
      open_api_spec: %OpenApi{} = api_spec
    } do
      %Operation{} = operation = api_spec.paths["/posts"].post
      %RequestBody{} = body = operation.requestBody
      schema = body.content["application/vnd.api+json"].schema
      attribute_props = schema.properties.data.properties.attributes.properties

      assert Map.has_key?(attribute_props, "name"),
             "expected public attribute 'name' to be present"

      refute Map.has_key?(attribute_props, "internal_notes"),
             "expected private attribute 'internal_notes' to be absent"
    end

    test "does not include private attributes in required list", %{
      open_api_spec: %OpenApi{} = api_spec
    } do
      %Operation{} = operation = api_spec.paths["/posts"].post
      %RequestBody{} = body = operation.requestBody
      schema = body.content["application/vnd.api+json"].schema
      required = schema.properties.data.properties.attributes.required || []

      refute "internal_notes" in required
    end
  end

  describe "hide_private?: false on create route" do
    test "includes private attributes in request body schema", %{
      open_api_spec: %OpenApi{} = api_spec
    } do
      %Operation{} = operation = api_spec.paths["/posts/exposed"].post
      %RequestBody{} = body = operation.requestBody
      schema = body.content["application/vnd.api+json"].schema
      attribute_props = schema.properties.data.properties.attributes.properties

      assert Map.has_key?(attribute_props, "name"),
             "expected public attribute 'name' to be present"

      assert Map.has_key?(attribute_props, "internal_notes"),
             "expected private attribute 'internal_notes' to be present when hide_private?: false"
    end
  end

  describe "hide_private?: true on update route" do
    test "excludes private attributes from request body schema", %{
      open_api_spec: %OpenApi{} = api_spec
    } do
      %Operation{} = operation = api_spec.paths["/posts/{id}"].patch
      %RequestBody{} = body = operation.requestBody
      schema = body.content["application/vnd.api+json"].schema
      attribute_props = schema.properties.data.properties.attributes.properties

      assert Map.has_key?(attribute_props, "name"),
             "expected public attribute 'name' to be present"

      refute Map.has_key?(attribute_props, "internal_notes"),
             "expected private attribute 'internal_notes' to be absent"
    end
  end

  describe "hide_private?: false on update route" do
    test "includes private attributes in request body schema", %{
      open_api_spec: %OpenApi{} = api_spec
    } do
      %Operation{} = operation = api_spec.paths["/posts/{id}/exposed"].patch
      %RequestBody{} = body = operation.requestBody
      schema = body.content["application/vnd.api+json"].schema
      attribute_props = schema.properties.data.properties.attributes.properties

      assert Map.has_key?(attribute_props, "name"),
             "expected public attribute 'name' to be present"

      assert Map.has_key?(attribute_props, "internal_notes"),
             "expected private attribute 'internal_notes' to be present when hide_private?: false"
    end
  end
end
