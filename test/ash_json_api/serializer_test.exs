# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.SerializerTest do
  use ExUnit.Case, async: true

  alias AshJsonApi.Serializer
  alias __MODULE__.{Blogs, Author, Post}

  defmodule Author do
    use Ash.Resource, domain: Blogs, data_layer: Ash.DataLayer.Ets

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
      count(:posts_count, :posts)
    end
  end

  defmodule Post do
    use Ash.Resource, domain: Blogs, data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:title, :string, public?: true)
      attribute(:body, :string)
    end

    relationships do
      belongs_to(:author, Author, public?: true, attribute_public?: false)
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :title, :body])
      end
    end

    calculations do
      calculate(:calc, :string, expr("calc"))
    end
  end

  defmodule Blogs do
    use Ash.Domain

    resources do
      resource Author
      resource Post
    end
  end

  describe "serialize_value/5" do
    test "serializes a string" do
      assert Serializer.serialize_value("string", Ash.Type.String, [], nil) == "string"
    end

    @tag :skip
    test "serializes a map" do
      assert Serializer.serialize_value(%{value: "string"}, Ash.Type.Map, [], nil) ==
               %{value: "string"}
    end

    test "serialize a array" do
      assert Serializer.serialize_value(["string"], {:array, Ash.Type.String}, [], nil) ==
               ["string"]
    end

    test "serializes a struct" do
      assert Serializer.serialize_value(
               %Post{title: "title"},
               Ash.Type.Struct,
               [instance_of: Post],
               Blogs
             ) ==
               %{id: nil, title: "title"}
    end

    test "serializes a resource" do
      post_id = Ash.UUID.generate()

      post =
        Post
        |> Ash.Changeset.for_create(:create, %{id: post_id, title: "title", body: "body"})
        |> Ash.create!()

      assert Serializer.serialize_value(post, Post, [], Blogs) ==
               %{id: post_id, title: "title"}
    end

    test "serializes a resource with load opt" do
      author_id = Ash.UUID.generate()
      post_id = Ash.UUID.generate()
      load = [:posts_count, posts: [:calc, :author]]

      author =
        Author
        |> Ash.Changeset.for_create(:create, %{id: author_id, name: "name"})
        |> Ash.Changeset.manage_relationship(
          :posts,
          [%{id: post_id, title: "title", body: "body"}],
          type: :create
        )
        |> Ash.create!()
        |> Ash.load!(load)

      assert Serializer.serialize_value(author, Author, [], Blogs, load: load) ==
               %{
                 id: author_id,
                 name: "name",
                 posts_count: 1,
                 posts: [
                   %{
                     id: post_id,
                     title: "title",
                     calc: "calc",
                     author: %{id: author_id, name: "name"}
                   }
                 ]
               }
    end
  end
end
