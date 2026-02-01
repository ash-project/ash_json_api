# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources do
  use ExUnit.Case
  @moduletag :json_api_spec_1_0

  defmodule Author do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      routes do
        base("/authors")
        get(:read)
        index(:read)
      end

      includes posts: [image: [file: []]]
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    relationships do
      has_many(:posts, AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Post,
        public?: true,
        destination_attribute: :author_id
      )
    end
  end

  defmodule Image do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("image")

      routes do
        base("/images")
        get(:read)
        index(:read)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    relationships do
      belongs_to(:file, AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.File,
        public?: true
      )

      has_many(:posts, AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Post,
        public?: true,
        destination_attribute: :image_id
      )
    end
  end

  defmodule File do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    ets do
      private?(true)
    end

    json_api do
      type("file")

      routes do
        base("/files")
        get(:read)
        index(:read)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    relationships do
      has_many(:images, AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Image,
        public?: true,
        destination_attribute: :file_id
      )
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    ets do
      private?(true)
    end

    json_api do
      type("post")

      routes do
        base("/posts")
        get(:read)
        index(:read)
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    relationships do
      belongs_to(:author, Author, public?: true)
      belongs_to(:image, Image, public?: true)

      has_many(:comments, AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Comment,
        public?: true
      )
    end
  end

  defmodule Comment do
    use Ash.Resource,
      domain: AshJsonApiTest.FetchingData.InclusionOfNestedRelatedResources.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    actions do
      default_accept(:*)
      defaults([:create, :read, :update, :destroy])
    end

    ets do
      private?(true)
    end

    json_api do
      type("comment")
      default_fields [:text, :calc]
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:text, :string, public?: true)
    end

    calculations do
      calculate(:calc, :string, expr("hello"))
    end

    relationships do
      belongs_to(:post, Post, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [
        AshJsonApi.Domain
      ]

    resources do
      resource(Author)
      resource(Image)
      resource(File)
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

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  # JSON:API 1.0 Specification
  # --------------------------
  # An endpoint MAY also support an include request parameter to allow the client to customize which related resources should be returned.
  # --------------------------
  describe "include request parameter with nested relations" do
    @describetag :spec_may

    test "resources endpoint with included param of to-many.to-one.to-one relationship" do
      # GET /authors/?include=posts.image.file

      file =
        %{id: file_id} =
        File
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      image =
        Image
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:file, file, type: :append_and_remove)
        |> Ash.create!()

      author =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.create!()

      _post_1 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "foo"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.Changeset.manage_relationship(:image, image, type: :append_and_remove)
        |> Ash.create!()

      _post_2 =
        Post
        |> Ash.Changeset.for_create(:create, %{name: "bar"})
        |> Ash.Changeset.manage_relationship(:author, author, type: :append_and_remove)
        |> Ash.Changeset.manage_relationship(:image, image, type: :append_and_remove)
        |> Ash.create!()

      assert %{
               resp_body: %{
                 "data" => [_ | _],
                 "included" => included
               }
             } = get(Domain, "/authors/?include=posts.image.file", status: 200)

      assert included_image = Enum.find(included, &(&1["id"] == image.id))

      assert %{
               "relationships" => %{
                 "file" => %{
                   "data" => %{
                     "id" => ^file_id,
                     "type" => "file"
                   }
                 }
               }
             } = included_image
    end
  end
end
