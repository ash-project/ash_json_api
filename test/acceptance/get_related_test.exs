# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.GetRelatedTest do
  use ExUnit.Case, async: true

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.GetRelatedTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("post")
      default_fields [:name, :content]

      routes do
        base("/posts")

        index :read do
          metadata(fn query, results, request ->
            %{
              "foo" => "bar"
            }
          end)
        end

        index :read do
          route "/read2"
          default_fields [:not_present_by_default]
        end
      end
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:content, :string, public?: true)
      attribute(:not_present_by_default, :string, public?: true)
    end

    relationships do
      has_many :comments, Test.Acceptance.GetRelatedTest.Comment do
        public?(true)
      end
    end

    calculations do
      calculate :name_twice, :string, concat([:name, :name], arg(:separator)) do
        argument(:separator, :string, default: "-")
        public?(true)
      end

      calculate :name_tripled, :string, concat([:name, :name, :name], arg(:separator)) do
        argument(:separator, :string, default: "-")
        public?(true)
      end
    end
  end

  defmodule Comment do
    use Ash.Resource,
      domain: Test.Acceptance.GetRelatedTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("comment")

      includes :post
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:content, :string, public?: true)
    end

    relationships do
      belongs_to(:post, Post) do
        public?(true)
      end
    end

    calculations do
      calculate :name_twice, :string, concat([:name, :name], arg(:separator)) do
        argument(:separator, :string, default: "-")
        public?(true)
      end

      calculate :name_tripled, :string, concat([:name, :name, :name], arg(:separator)) do
        argument(:separator, :string, default: "-")
        public?(true)
      end
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

      routes do
        base_route "/posts", Post do
          index :read
          related :comments, :read, primary?: true
        end
      end
    end

    resources do
      resource(Post)
      resource(Comment)
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

  describe "GET /:id with invalid filter and includes" do
    test "returns JSON:API error document instead of crashing with KeyError" do
      # Create a post with comments
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "John Doe", content: "Test post"})
        |> Ash.create!()

      _comment =
        Comment
        |> Ash.Changeset.for_create(:create, %{
          name: "Test comment",
          content: "comment",
          post_id: post.id
        })
        |> Ash.create!()

      # This request triggers a filter error in fetch_record_from_path when the ID
      # format is invalid. The bug would cause a KeyError because fetch_record_from_path
      # returned {:error, request} instead of just request, and chain/3 would try to
      # access request.errors on the tuple.
      #
      # With the fix, this returns a proper 404 error document
      response =
        Domain
        |> get("/posts/invalid-id-format/comments?include=post", status: 404)

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
        |> get("/posts/#{non_existent_id}/comments?include=post", status: 404)

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

    test "handles non-existent ID with complex includes gracefully" do
      # Use a non-existent ID to trigger the error path in fetch_record_from_path
      # This exercises the code path where the lookup fails and we need to add an error
      non_existent_id = Ash.UUID.generate()

      # Before the fix, this would crash with KeyError when chain/3 tried to access
      # request.errors on {:error, request}. After the fix, it returns proper 404.
      response =
        Domain
        |> get("/posts/#{non_existent_id}/comments?include=post", status: 404)

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

  describe "index endpoint" do
    setup do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "parent", content: "parent"})
        |> Ash.create!()

      comments =
        Enum.map(0..1, fn i ->
          Comment
          |> Ash.Changeset.for_create(:create, %{
            name: "comment#{i}",
            content: "comment",
            post_id: post.id
          })
          |> Ash.create!()
        end)

      %{post: post, comments: comments}
    end

    test "returns a list of posts", %{post: post} do
      Domain
      |> get("/posts/#{post.id}/comments", status: 200)
      |> assert_data_matches([
        %{
          "attributes" => %{
            "name" => "comment" <> _,
            "content" => "comment"
          },
          "type" => "comment"
        },
        %{
          "attributes" => %{
            "name" => "comment" <> _,
            "content" => "comment"
          },
          "type" => "comment"
        }
      ])
    end

    test "additional relationships can be included", %{post: post} do
      includes =
        Domain
        |> get("/posts/#{post.id}/comments?include=post", status: 200)
        |> assert_data_matches([
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          },
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          }
        ])
        |> Map.get(:resp_body)
        |> get_in(["included"])

      assert [
               %{
                 "attributes" => %{"content" => "parent", "name" => "parent"},
                 "type" => "post"
               }
             ] = includes
    end

    test "field_inputs can be supplied on includes", %{post: post} do
      includes =
        Domain
        |> get(
          "/posts/#{post.id}/comments?include=post&fields[post]=name_twice&field_inputs[post][name_twice][separator]=baz",
          status: 200
        )
        |> assert_data_matches([
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          },
          %{
            "attributes" => %{
              "name" => "comment" <> _,
              "content" => "comment"
            },
            "type" => "comment"
          }
        ])
        |> Map.get(:resp_body)
        |> get_in(["included"])

      assert [
               %{
                 "attributes" => %{"name_twice" => "parentbazparent"},
                 "type" => "post"
               }
             ] = includes
    end
  end
end
