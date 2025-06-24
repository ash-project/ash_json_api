defmodule Test.Acceptance.PostTest do
  use ExUnit.Case, async: true

  defmodule Review do
    use Ash.Resource,
      data_layer: :embedded

    actions do
      default_accept(:*)
      defaults([:read, :create, :update, :destroy])
    end

    attributes do
      attribute(:reviewer, :string, public?: true)
      attribute(:rating, :integer, public?: true)
    end
  end

  defmodule Author do
    use Ash.Resource,
      domain: Test.Acceptance.PostTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("author")

      routes do
        base("/authors")
        get(:read)
        index(:read)

        post :confirm_name do
          route "/confirm_name"

          metadata(fn changeset, result, request ->
            %{"bar" => "foo"}
          end)
        end

        post :create_fake do
          route "/fake"
        end

        post :with_age do
          route "/with_age"
        end

        post :sign_in do
          route "/sign_in/:id"

          modify_conn(fn conn, _subject, result, _request ->
            Plug.Conn.put_resp_header(
              conn,
              "authorization",
              "Bearer: #{result.__metadata__.token}"
            )
          end)
        end

        post :import do
          route "/import"
        end
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])
      create(:create, primary?: true)

      create :confirm_name do
        argument(:confirm, :string, allow_nil?: false)
        validate(confirm(:name, :confirm))
      end

      create :with_age do
        accept([:age])
        validate(numericality(:age, greater_than: &__MODULE__.zero/0))
      end

      create :import do
        argument(:file, :file, allow_nil?: false)

        change(fn changeset, _context ->
          {:ok, device} = Ash.Type.File.open(changeset.arguments.file)

          Ash.Changeset.change_attribute(changeset, :name, IO.read(device, :eof))
        end)
      end

      read :sign_in do
        argument(:id, :string, allow_nil?: false)
        # we ignore this, its just here for sake of demonstration
        argument(:password, :string, allow_nil?: false)

        metadata(:token, :string)

        filter(expr(id == ^arg(:id)))

        prepare(
          after_action(fn
            query, [], context ->
              {:error,
               Ash.Error.Query.NotFound.exception(
                 resource: query.resource,
                 filter: %{id: query.arguments.id}
               )}

            query, [result], context ->
              {:ok,
               Ash.Resource.set_metadata(result, %{token: "super-secret-token-#{result.id}"})}
          end)
        )
      end

      action :create_fake, :struct do
        constraints(instance_of: __MODULE__)

        run(fn _, _ ->
          {:ok,
           %__MODULE__{
             name: "fake"
           }}
        end)
      end
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, public?: true)
      attribute(:age, :integer, public?: true)
    end

    relationships do
      has_many(:posts, Test.Acceptance.PostTest.Post,
        destination_attribute: :author_id,
        public?: true
      )
    end

    def zero, do: 0
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.Acceptance.PostTest.Domain,
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

        post(:create,
          relationship_arguments: [:author],
          default_fields: [:name, :email, :hidden, :name_twice]
        )

        post(:accepts_email,
          upsert?: true,
          upsert_identity: :unique_email,
          route: "/upsert_by_email"
        )
      end
    end

    actions do
      default_accept(:*)
      defaults([:read, :update, :destroy])

      create :create do
        primary? true
        accept([:id, :name, :hidden, :review, :some_atom])

        argument(:author, :map)

        change(manage_relationship(:author, type: :append_and_remove))
      end

      create :accepts_email do
        accept([:name, :email])
      end
    end

    identities do
      identity(:unique_email, [:email], pre_check_with: Test.Acceptance.PostTest.Domain)
    end

    attributes do
      uuid_primary_key(:id, writable?: true)
      attribute(:name, :string, allow_nil?: false, public?: true)
      attribute(:hidden, :string, public?: true)

      attribute(:email, :string,
        public?: true,
        allow_nil?: true,
        constraints: [
          match: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
        ]
      )

      attribute(:some_atom, :atom,
        public?: true,
        constraints: [one_of: [:foo, :bar]]
      )

      attribute(:review, Test.Acceptance.PostTest.Review, public?: true)
    end

    relationships do
      belongs_to(:author, Test.Acceptance.PostTest.Author, allow_nil?: true, public?: true)
    end

    calculations do
      calculate :name_twice, :string, concat([:name, :name], arg(:separator)) do
        argument(:separator, :string, default: "-")
        public?(true)
      end
    end
  end

  defmodule Pin do
    use Ash.Resource,
      domain: Test.Acceptance.PostTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [
        AshJsonApi.Resource
      ]

    ets do
      private?(true)
    end

    json_api do
      type("pin")

      routes do
        base("/pins")

        post(:create)
      end
    end

    actions do
      create :create do
        primary? true
        accept([:pin])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:pin, :string)
    end

    validations do
      validate(match(:pin, "^[0-9]{4}$"))
      validate(string_length(:pin, exact: 4))
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
      resource(Author)
      resource(Post)
      resource(Pin)
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

  describe "invalid_post" do
    @describetag :attributes
    test "create without all attributes in accept list" do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 1"
            }
          }
        })

      assert %{"data" => %{"attributes" => %{"hidden" => nil}}} = response.resp_body
    end

    test "create with validation that uses a function" do
      response =
        Domain
        |> post("/authors/with_age", %{
          data: %{
            type: "author",
            attributes: %{
              age: -1
            }
          }
        })

      # Make sure we get correct error code back
      assert response.status == 400
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "invalid_attribute"
      assert error["source"] == %{"pointer" => "/data/attributes/age"}
      assert error["detail"] == "must be greater than %{greater_than}"
      assert error["meta"]["greater_than"] == 0
    end
  end

  describe "post" do
    @describetag :attributes
    test "create with all attributes in accept list" do
      id = Ecto.UUID.generate()

      Domain
      |> post("/posts?field_inputs[post][name_twice][separator]=bar", %{
        data: %{
          type: "post",
          attributes: %{
            id: id,
            name: "Post 1",
            hidden: "hidden",
            some_atom: "foo"
          }
        }
      })
      |> assert_attribute_equals("email", nil)
      |> assert_attribute_equals("name_twice", "Post 1barPost 1")
    end

    test "a read can be called, and it can modify the conn" do
      %{id: author_id} =
        Author
        |> Ash.Changeset.for_create(:create, %{name: "fred"})
        |> Ash.create!()

      resp =
        Domain
        |> post(
          "/authors/sign_in/#{author_id}",
          %{
            data: %{
              type: "author",
              attributes: %{
                password: "password"
              }
            }
          },
          status: 201
        )

      assert Plug.Conn.get_resp_header(resp, "authorization") ==
               ["Bearer: super-secret-token-#{author_id}"]

      assert resp.resp_body["data"]["attributes"]["name"] == "fred"
    end

    test "create with generic action" do
      Domain
      |> post(
        "/authors/fake",
        %{
          data: %{
            type: "author",
            attributes: %{}
          }
        },
        status: 201
      )
      |> assert_data_equals(%{
        "attributes" => %{"name" => "fake", "age" => nil},
        "id" => nil,
        "links" => %{},
        "meta" => %{},
        "relationships" => %{"posts" => %{"links" => %{}, "meta" => %{}}},
        "type" => "author"
      })
    end

    test "create with base64 import file" do
      resp =
        post(
          Domain,
          "/authors/import",
          %{
            data: %{
              type: "author",
              attributes: %{
                file: Base.encode64("imported name")
              }
            }
          },
          status: 201
        )

      assert resp.resp_body["data"]["attributes"]["name"] == "imported name"
    end

    test "create with invalid base64 import file" do
      response =
        post(
          Domain,
          "/authors/import",
          %{
            data: %{
              type: "author",
              attributes: %{
                file: "not base64"
              }
            }
          },
          status: 400
        )

      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "invalid_field"
    end

    test "create with multipart import file" do
      import_file_ref = "~~import~~"

      resp =
        multipart_post(
          Domain,
          "/authors/import",
          Multipart.new()
          |> Multipart.add_part(
            Multipart.Part.file_content_field(
              import_file_ref,
              "imported name",
              import_file_ref,
              [],
              filename: "import.txt",
              content_type: "text/plain"
            )
          )
          |> Multipart.add_part(
            Multipart.Part.file_content_field(
              "data",
              Jason.encode!(%{
                type: "author",
                attributes: %{
                  file: import_file_ref
                }
              }),
              "data",
              [],
              content_type: "application/vnd.api+json"
            )
          ),
          status: 201
        )

      assert resp.resp_body["data"]["attributes"]["name"] == "imported name"
    end

    test "create with unknown input in embed generates correct error code" do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Post3",
              review: %{
                unknown_attr: "Foo"
              }
            }
          }
        })

      # Make sure we get correct error code back
      assert response.status == 422
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "no_such_input"
    end

    test "nested errors have the correct source pointer" do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Hello",
              review: %{
                reviewer: "foo",
                rating: "bar"
              }
            }
          }
        })

      # response is a Plug.
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "invalid_attribute"
      assert error["source"] == %{"pointer" => "/data/attributes/review/rating"}
    end

    test "error validation using match with a regex" do
      response =
        Domain
        |> post(
          "/pins",
          %{
            data: %{
              type: "pin",
              attributes: %{pin: "12a"}
            }
          },
          status: 400
        )

      # response is a Plug.
      assert %{"errors" => [error_regex, error_length]} = response.resp_body

      assert error_regex["code"] == "invalid_attribute"
      assert error_regex["detail"] == "must match \"^[0-9]{4}$\""
      assert error_regex["meta"] == %{"match" => "^[0-9]{4}$"}
      assert error_regex["source"] == %{"pointer" => "/data/attributes/pin"}

      assert error_length["code"] == "invalid_attribute"
      assert error_length["detail"] == "must have length of exactly %{exact}"
      assert error_length["meta"] == %{"exact" => 4}
      assert error_length["source"] == %{"pointer" => "/data/attributes/pin"}
    end
  end

  test "post with upsert" do
    post =
      Ash.create!(
        Ash.Changeset.for_create(Post, :create, %{name: "Post"})
        |> Ash.Changeset.force_change_attribute(:email, "foo@bar.com")
      )

    Domain
    |> post("/posts/upsert_by_email", %{
      data: %{
        type: "post",
        attributes: %{
          name: "New Post",
          email: post.email
        }
      }
    })
    |> assert_attribute_equals("name", "New Post")
    |> assert_id_equals(post.id)
  end

  describe "post_email_id_exception" do
    test "create with all attributes in accept list with email" do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 2",
              hidden: "hidden",
              email: "dummy@test.com"
            }
          }
        })

      # response is a Plug.
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "invalid_body"
      assert error["source"] == %{"pointer" => "/data/attributes/email"}

      assert error["detail"] ==
               "Expected only defined properties, got key [\"data\", \"attributes\", \"email\"]."
    end
  end

  describe "post_email_id_relationship" do
    setup do
      author =
        Author
        |> Ash.Changeset.for_create(:create, %{id: Ecto.UUID.generate(), name: "John"})
        |> Ash.create!()

      %{author: author}
    end

    test "create with all attributes in accept list without email along with relationship", %{
      author: author
    } do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Post 2",
              hidden: "hidden"
            },
            relationships: %{
              author: %{
                data: %{id: author.id, type: "author"}
              }
            }
          }
        })

      # response is a Plug.
      assert %{"data" => %{"attributes" => %{"hidden" => "hidden"}}} = response.resp_body
    end

    test "creating with invalid relationships displays the correct error" do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Post 2",
              hidden: "hidden"
            },
            relationships: %{
              author: %{
                data: "foo"
              }
            }
          }
        })

      # response is a Plug.
      assert %{
               "errors" => [
                 %{
                   "code" => "invalid_body",
                   "detail" => "invalid relationship input",
                   "source" => %{"pointer" => "/data/relationships/author"},
                   "status" => "400",
                   "title" => "InvalidBody"
                 }
               ],
               "jsonapi" => %{"version" => "1.0"}
             } = response.resp_body
    end

    test "create with all attributes in accept list with email along with relationship", %{
      author: author
    } do
      id = Ecto.UUID.generate()

      response =
        Domain
        |> post("/posts", %{
          data: %{
            type: "post",
            attributes: %{
              id: id,
              name: "Invalid Post 3",
              hidden: "hidden",
              email: "dummy@test.com"
            },
            relationships: %{
              author: %{
                data: %{id: author.id, type: "author"}
              }
            }
          }
        })

      # response is a Plug.
      assert %{"errors" => [error]} = response.resp_body
      assert error["code"] == "invalid_body"
      assert error["source"] == %{"pointer" => "/data/attributes/email"}

      assert error["detail"] ==
               "Expected only defined properties, got key [\"data\", \"attributes\", \"email\"]."
    end

    test "arguments are validated properly" do
      Domain
      |> post(
        "/authors/confirm_name",
        %{
          data: %{
            type: "author",
            attributes: %{
              name: "foo",
              confirm: "bar"
            }
          }
        },
        status: 400
      )
    end

    test "arguments are threaded through properly" do
      Domain
      |> post(
        "/authors/confirm_name",
        %{
          data: %{
            type: "author",
            attributes: %{
              name: "foo",
              confirm: "foo"
            }
          }
        },
        status: 201
      )
      |> assert_meta_equals(%{"bar" => "foo"})
    end
  end
end
