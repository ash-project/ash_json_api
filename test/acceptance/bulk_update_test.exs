# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.BulkUpdateTest do
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.BulkUpdateTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("post")

      routes do
        base("/posts")
        get(:read)
        index(:read)
        post(:create)
        patch(:update)

        bulk_update(:update)

        bulk_update :update do
          route("/bulk_atomic")
          transaction(:all)
        end
      end
    end

    actions do
      default_accept([:*])
      defaults([:read, :destroy, create: :*])

      update :update do
        primary?(true)
        require_atomic?(false)
        accept([:name])

        validate(fn changeset, _context ->
          if Ash.Changeset.get_attribute(changeset, :name) == "FAIL" do
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :name,
               message: "is invalid"
             )}
          else
            :ok
          end
        end)
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true, public?: true)
      attribute(:name, :string, public?: true, allow_nil?: false)
    end
  end

  defmodule Enrollment do
    use Ash.Resource,
      domain: Test.Acceptance.BulkUpdateTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("enrollment")

      primary_key do
        keys([:student_id, :course_id])
        delimiter("-")
      end

      routes do
        base("/enrollments")
        index(:read)
        bulk_update(:update)
      end
    end

    actions do
      default_accept([:*])
      defaults([:read, create: :*])

      update :update do
        primary?(true)
        require_atomic?(false)
        accept([:grade])

        validate(fn changeset, _context ->
          if Ash.Changeset.get_attribute(changeset, :grade) == "FAIL" do
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(field: :grade, message: "is invalid")}
          else
            :ok
          end
        end)
      end
    end

    attributes do
      attribute(:student_id, :string, primary_key?: true, allow_nil?: false, public?: true)
      attribute(:course_id, :string, primary_key?: true, allow_nil?: false, public?: true)
      attribute(:grade, :string, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      log_errors?(false)
    end

    resources do
      resource(Post)
      resource(Enrollment)
    end
  end

  defmodule Router do
    use AshJsonApi.Router, domain: Domain
  end

  import AshJsonApi.Test

  setup do
    Application.put_env(:ash_json_api, Domain, json_api: [test_router: Router])

    posts =
      Enum.map(1..3, fn i ->
        Post
        |> Ash.Changeset.for_create(:create, %{id: Ecto.UUID.generate(), name: "Post #{i}"})
        |> Ash.create!()
      end)

    %{posts: posts}
  end

  describe "partial success" do
    test "some ids fail -> 207 with data, errors and meta", %{posts: [p1, p2, p3]} do
      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "updated 1"}},
              %{type: "post", id: p2.id, attributes: %{name: "FAIL"}},
              %{type: "post", id: p3.id, attributes: %{name: "updated 3"}}
            ]
          },
          status: 207
        )

      assert %{"data" => data, "errors" => errors, "meta" => meta} = response.resp_body

      assert meta == %{"total_requested" => 3, "successful" => 2, "failed" => 1}

      assert length(data) == 2
      ids = Enum.map(data, & &1["id"])
      assert p1.id in ids
      assert p3.id in ids
      refute p2.id in ids

      names = Enum.map(data, &get_in(&1, ["attributes", "name"]))
      assert "updated 1" in names
      assert "updated 3" in names

      assert [error] = errors
      assert error["source"]["pointer"] == "/data/1/attributes/name"
    end
  end

  describe "all success" do
    test "every id succeeds -> 200 with only data", %{posts: [p1, p2, _p3]} do
      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "updated 1"}},
              %{type: "post", id: p2.id, attributes: %{name: "updated 2"}}
            ]
          },
          status: 200
        )

      assert %{"data" => data} = response.resp_body
      assert length(data) == 2
      refute Map.has_key?(response.resp_body, "errors")

      names = Enum.map(data, &get_in(&1, ["attributes", "name"]))
      assert "updated 1" in names
      assert "updated 2" in names
    end
  end

  describe "transactional batch (atomic)" do
    test "all succeed -> 200 with a plain collection", %{posts: [p1, p2, _p3]} do
      response =
        Domain
        |> patch(
          "/posts/bulk_atomic",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "updated 1"}},
              %{type: "post", id: p2.id, attributes: %{name: "updated 2"}}
            ]
          },
          status: 200
        )

      assert %{"data" => data} = response.resp_body
      assert length(data) == 2
      refute Map.has_key?(response.resp_body, "errors")
    end

    test "any failure rolls the whole request back -> standard errors document", %{
      posts: [p1, p2, _p3]
    } do
      response =
        Domain
        |> patch(
          "/posts/bulk_atomic",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "FAIL"}},
              %{type: "post", id: p2.id, attributes: %{name: "would-be-ok"}}
            ]
          },
          status: 400
        )

      refute Map.has_key?(response.resp_body, "data")
      assert %{"errors" => errors} = response.resp_body
      assert errors != []
    end

    test "a missing id fails the whole atomic request with a 404", %{posts: [p1, _p2, _p3]} do
      missing_id = Ecto.UUID.generate()

      response =
        Domain
        |> patch(
          "/posts/bulk_atomic",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "updated 1"}},
              %{type: "post", id: missing_id, attributes: %{name: "whatever"}}
            ]
          },
          status: 404
        )

      refute Map.has_key?(response.resp_body, "data")
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "not_found"
    end
  end

  describe "all failed (per-record)" do
    test "every id fails -> a standard errors document (no data, no 207)", %{
      posts: [p1, p2, _p3]
    } do
      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "FAIL"}},
              %{type: "post", id: p2.id, attributes: %{name: "FAIL"}}
            ]
          },
          status: 400
        )

      refute Map.has_key?(response.resp_body, "data")
      assert %{"errors" => errors} = response.resp_body
      assert length(errors) == 2

      pointers = Enum.map(errors, &get_in(&1, ["source", "pointer"]))
      assert "/data/0/attributes/name" in pointers
      assert "/data/1/attributes/name" in pointers
    end
  end

  describe "source pointers" do
    test "attribute errors point at /data/<index>/attributes/<field>", %{posts: [p1, p2, _p3]} do
      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "FAIL"}},
              %{type: "post", id: p2.id, attributes: %{name: "ok"}}
            ]
          },
          status: 207
        )

      assert [error] = response.resp_body["errors"]
      assert error["source"]["pointer"] == "/data/0/attributes/name"
    end
  end

  describe "missing id" do
    test "an unknown id surfaces as NotFound at its index, others still succeed", %{
      posts: [p1, _p2, _p3]
    } do
      missing_id = Ecto.UUID.generate()

      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "updated 1"}},
              %{type: "post", id: missing_id, attributes: %{name: "whatever"}}
            ]
          },
          status: 207
        )

      assert %{"data" => [datum], "errors" => [error], "meta" => meta} = response.resp_body
      assert datum["id"] == p1.id
      assert error["code"] == "not_found"
      assert error["source"]["pointer"] == "/data/1"
      assert meta == %{"total_requested" => 2, "successful" => 1, "failed" => 1}
    end
  end

  describe "coexistence with a single patch route" do
    test "PATCH /posts/bulk hits the bulk route, PATCH /posts/:id hits the single route", %{
      posts: [p1, _p2, _p3]
    } do
      # bulk route
      Domain
      |> patch(
        "/posts/bulk",
        %{data: [%{type: "post", id: p1.id, attributes: %{name: "bulk name"}}]},
        status: 200
      )

      # single record route still works at /:id
      response =
        Domain
        |> patch(
          "/posts/#{p1.id}",
          %{data: %{type: "post", id: p1.id, attributes: %{name: "single name"}}},
          status: 200
        )

      assert get_in(response.resp_body, ["data", "attributes", "name"]) == "single name"
    end
  end

  describe "openapi" do
    test "advertises an array request body and a 207 response" do
      spec = AshJsonApi.OpenApi.spec(domain: [Domain])

      operation = spec.paths["/posts/bulk"].patch
      assert operation

      data_schema =
        operation.requestBody.content["application/vnd.api+json"].schema.properties.data

      assert data_schema.type == :array
      assert data_schema.items.properties.id

      assert Map.has_key?(operation.responses, 207)
      assert Map.has_key?(operation.responses, 200)

      response_props =
        operation.responses[207].content["application/vnd.api+json"].schema.properties

      assert response_props.data.type == :array
      assert response_props.errors.type == :array
      assert response_props.meta.properties.total_requested
    end
  end

  describe "composite primary keys" do
    setup do
      enrollments =
        for {s, c} <- [{"s1", "c1"}, {"s2", "c2"}] do
          Enrollment
          |> Ash.Changeset.for_create(:create, %{student_id: s, course_id: c, grade: "A"})
          |> Ash.create!()
        end

      %{enrollments: enrollments}
    end

    test "bulk updates records addressed by composite id", %{enrollments: [e1, e2]} do
      response =
        Domain
        |> patch(
          "/enrollments/bulk",
          %{
            data: [
              %{
                type: "enrollment",
                id: "#{e1.student_id}-#{e1.course_id}",
                attributes: %{grade: "B"}
              },
              %{
                type: "enrollment",
                id: "#{e2.student_id}-#{e2.course_id}",
                attributes: %{grade: "FAIL"}
              }
            ]
          },
          status: 207
        )

      assert %{"data" => [datum], "errors" => [error], "meta" => meta} = response.resp_body
      assert datum["id"] == "#{e1.student_id}-#{e1.course_id}"
      assert get_in(datum, ["attributes", "grade"]) == "B"
      assert error["source"]["pointer"] == "/data/1/attributes/grade"
      assert meta == %{"total_requested" => 2, "successful" => 1, "failed" => 1}
    end

    test "an unknown composite id surfaces as NotFound at its index", %{enrollments: [e1, _e2]} do
      response =
        Domain
        |> patch(
          "/enrollments/bulk",
          %{
            data: [
              %{
                type: "enrollment",
                id: "#{e1.student_id}-#{e1.course_id}",
                attributes: %{grade: "B"}
              },
              %{type: "enrollment", id: "nope-missing", attributes: %{grade: "C"}}
            ]
          },
          status: 207
        )

      assert %{"data" => [datum], "errors" => [error]} = response.resp_body
      assert datum["id"] == "#{e1.student_id}-#{e1.course_id}"
      assert error["code"] == "not_found"
      assert error["source"]["pointer"] == "/data/1"
    end
  end

  describe "edge cases" do
    test "an empty data array -> 200 with an empty collection" do
      response =
        Domain
        |> patch("/posts/bulk", %{data: []}, status: 200)

      assert response.resp_body["data"] == []
      refute Map.has_key?(response.resp_body, "errors")
    end
  end

  describe "malformed body" do
    test "a missing id member is reported as an invalid_body error", %{posts: [p1, _p2, _p3]} do
      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "updated 1"}},
              %{type: "post", attributes: %{name: "no id"}}
            ]
          },
          status: 400
        )

      assert Enum.any?(response.resp_body["errors"], fn error ->
               error["code"] == "invalid_body" and error["source"]["pointer"] == "/data/1/id"
             end)
    end

    test "a member with the wrong type is reported at /data/<index>/type", %{
      posts: [p1, _p2, _p3]
    } do
      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{
            data: [
              %{type: "post", id: p1.id, attributes: %{name: "ok"}},
              %{type: "not-a-post", id: Ecto.UUID.generate(), attributes: %{name: "x"}}
            ]
          },
          status: 400
        )

      assert Enum.any?(response.resp_body["errors"], fn error ->
               error["source"]["pointer"] == "/data/1/type"
             end)
    end

    test "a non-list data is rejected", %{posts: [p1, _p2, _p3]} do
      response =
        Domain
        |> patch(
          "/posts/bulk",
          %{data: %{type: "post", id: p1.id, attributes: %{name: "x"}}},
          status: 400
        )

      assert %{"errors" => errors} = response.resp_body
      assert errors != []
    end
  end
end
