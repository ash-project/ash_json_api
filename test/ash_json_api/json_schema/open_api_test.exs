# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.OpenApiTest do
  use ExUnit.Case, async: true

  alias AshJsonApi.OpenApi
  alias __MODULE__.{Blogs, Author, Post}

  defmodule Author do
    use Ash.Resource,
      domain: Blogs,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    json_api do
      type("author")
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, public?: true)
    end

    relationships do
      has_many(:posts, Post, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :name])
      end
    end

    aggregates do
      count(:posts_count, :posts, description: "Count of posts")
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Blogs,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    json_api do
      type("post")
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:view_count, :integer, public?: true, description: "View count of the post")
    end

    relationships do
      belongs_to(:author, Author, public?: true, attribute_public?: false)
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :view_count])
      end
    end

    calculations do
      calculate(:calc, :string, expr("calc"), description: "A calculation")
    end
  end

  defmodule Blogs do
    use Ash.Domain

    resources do
      resource Author
      resource Post
    end
  end

  describe "filter_type/2" do
    test "with attribute" do
      resource = Post
      attribute = Ash.Resource.Info.attribute(Post, :view_count)

      {result, _acc} = OpenApi.filter_type(attribute, resource, OpenApi.empty_acc())

      assert result == [
               {"post-filter-view_count",
                %OpenApiSpex.Schema{
                  type: :object,
                  description: "View count of the post",
                  properties: %{
                    in: %OpenApiSpex.Schema{
                      type: :array,
                      items: %OpenApiSpex.Schema{type: :integer}
                    },
                    eq: %OpenApiSpex.Schema{type: :integer},
                    is_nil: %OpenApiSpex.Schema{type: :boolean},
                    not_eq: %OpenApiSpex.Schema{type: :integer},
                    less_than: %OpenApiSpex.Schema{type: :integer},
                    greater_than: %OpenApiSpex.Schema{type: :integer},
                    less_than_or_equal: %OpenApiSpex.Schema{type: :integer},
                    greater_than_or_equal: %OpenApiSpex.Schema{type: :integer}
                  },
                  additionalProperties: false
                }}
             ]
    end

    test "with aggregate" do
      resource = Author
      aggregate = Ash.Resource.Info.aggregate(Author, :posts_count)

      {result, _acc} = OpenApi.filter_type(aggregate, resource, OpenApi.empty_acc())

      assert result == [
               {
                 "author-filter-posts_count",
                 %OpenApiSpex.Schema{
                   type: :object,
                   properties: %{
                     in: %OpenApiSpex.Schema{
                       type: :array,
                       items: %OpenApiSpex.Schema{type: :integer}
                     },
                     eq: %OpenApiSpex.Schema{type: :integer},
                     is_nil: %OpenApiSpex.Schema{type: :boolean},
                     not_eq: %OpenApiSpex.Schema{type: :integer},
                     less_than: %OpenApiSpex.Schema{type: :integer},
                     greater_than: %OpenApiSpex.Schema{type: :integer},
                     less_than_or_equal: %OpenApiSpex.Schema{type: :integer},
                     greater_than_or_equal: %OpenApiSpex.Schema{type: :integer}
                   },
                   additionalProperties: false,
                   description: "Count of posts"
                 }
               }
             ]
    end

    test "with calculation" do
      resource = Post
      calculation = Ash.Resource.Info.calculation(Post, :calc)

      {result, _acc} = OpenApi.filter_type(calculation, resource, OpenApi.empty_acc())

      assert result == [
               {"post-filter-calc",
                %OpenApiSpex.Schema{
                  type: :object,
                  description: "A calculation",
                  properties: %{
                    in: %OpenApiSpex.Schema{
                      type: :array,
                      items: %OpenApiSpex.Schema{type: :string}
                    },
                    eq: %OpenApiSpex.Schema{type: :string},
                    is_nil: %OpenApiSpex.Schema{type: :boolean},
                    not_eq: %OpenApiSpex.Schema{type: :string},
                    less_than: %OpenApiSpex.Schema{type: :string},
                    greater_than: %OpenApiSpex.Schema{type: :string},
                    less_than_or_equal: %OpenApiSpex.Schema{type: :string},
                    greater_than_or_equal: %OpenApiSpex.Schema{type: :string},
                    contains: %OpenApiSpex.Schema{type: :string}
                  },
                  required: [],
                  additionalProperties: false
                }}
             ]
    end
  end

  describe "raw_filter_type/2" do
    test "with attribute" do
      resource = Post
      attribute = Ash.Resource.Info.attribute(Post, :view_count)

      {result, _acc} = OpenApi.raw_filter_type(attribute, resource, OpenApi.empty_acc())

      assert result == %OpenApiSpex.Schema{
               type: :object,
               description: "View count of the post",
               properties: %{
                 in: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :integer}},
                 eq: %OpenApiSpex.Schema{type: :integer},
                 is_nil: %OpenApiSpex.Schema{type: :boolean},
                 not_eq: %OpenApiSpex.Schema{type: :integer},
                 less_than: %OpenApiSpex.Schema{type: :integer},
                 greater_than: %OpenApiSpex.Schema{type: :integer},
                 less_than_or_equal: %OpenApiSpex.Schema{type: :integer},
                 greater_than_or_equal: %OpenApiSpex.Schema{type: :integer}
               },
               additionalProperties: false
             }
    end

    test "with aggregate" do
      resource = Author
      aggregate = Ash.Resource.Info.aggregate(Author, :posts_count)

      {result, _acc} = OpenApi.raw_filter_type(aggregate, resource, OpenApi.empty_acc())

      assert result == %OpenApiSpex.Schema{
               type: :object,
               properties: %{
                 in: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :integer}},
                 eq: %OpenApiSpex.Schema{type: :integer},
                 is_nil: %OpenApiSpex.Schema{type: :boolean},
                 greater_than: %OpenApiSpex.Schema{type: :integer},
                 not_eq: %OpenApiSpex.Schema{type: :integer},
                 less_than: %OpenApiSpex.Schema{type: :integer},
                 less_than_or_equal: %OpenApiSpex.Schema{type: :integer},
                 greater_than_or_equal: %OpenApiSpex.Schema{type: :integer}
               },
               additionalProperties: false,
               description: "Count of posts"
             }
    end

    test "with calculation" do
      resource = Post
      calculation = Ash.Resource.Info.calculation(Post, :calc)

      {result, _acc} = OpenApi.raw_filter_type(calculation, resource, OpenApi.empty_acc())

      assert result == %OpenApiSpex.Schema{
               type: :object,
               description: "A calculation",
               properties: %{
                 in: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}},
                 eq: %OpenApiSpex.Schema{type: :string},
                 is_nil: %OpenApiSpex.Schema{type: :boolean},
                 not_eq: %OpenApiSpex.Schema{type: :string},
                 less_than: %OpenApiSpex.Schema{type: :string},
                 greater_than: %OpenApiSpex.Schema{type: :string},
                 less_than_or_equal: %OpenApiSpex.Schema{type: :string},
                 greater_than_or_equal: %OpenApiSpex.Schema{type: :string},
                 contains: %OpenApiSpex.Schema{type: :string}
               },
               required: [],
               additionalProperties: false
             }
    end
  end
end
