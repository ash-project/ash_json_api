# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.GenericActionIndexTest do
  use ExUnit.Case, async: true

  defmodule SearchResult do
    use Ash.Resource,
      domain: Test.Acceptance.GenericActionIndexTest.Domain,
      extensions: [AshJsonApi.Resource]

    resource do
      require_primary_key?(false)
    end

    json_api do
      type("search_result")

      routes do
        base("/search")
        route(:get, "/", :search, query_params: [:query, :category])
      end
    end

    actions do
      action :search, {:array, :struct} do
        constraints(items: [instance_of: __MODULE__])
        argument(:query, :string, allow_nil?: false)
        argument(:category, :string, allow_nil?: true)

        run(fn input, _ ->
          query = input.arguments.query
          category = Map.get(input.arguments, :category)

          results =
            case category do
              nil ->
                [
                  %__MODULE__{title: "Result 1 for #{query}", content: "Content 1"},
                  %__MODULE__{title: "Result 2 for #{query}", content: "Content 2"}
                ]

              category ->
                [
                  %__MODULE__{
                    title: "#{category} Result 1 for #{query}",
                    content: "Category content 1"
                  },
                  %__MODULE__{
                    title: "#{category} Result 2 for #{query}",
                    content: "Category content 2"
                  }
                ]
            end

          {:ok, results}
        end)
      end
    end

    attributes do
      attribute(:title, :string, public?: true)
      attribute(:content, :string, public?: true)
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
      resource(SearchResult)
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

  test "generic action index route with required argument" do
    response =
      Domain
      |> get("/search?query=elixir", status: 200)

    assert response.resp_body == [
             %{
               "title" => "Result 1 for elixir",
               "content" => "Content 1"
             },
             %{
               "title" => "Result 2 for elixir",
               "content" => "Content 2"
             }
           ]
  end

  test "generic action index route with optional argument" do
    response =
      Domain
      |> get("/search?query=elixir&category=tutorial", status: 200)

    assert response.resp_body == [
             %{
               "title" => "tutorial Result 1 for elixir",
               "content" => "Category content 1"
             },
             %{
               "title" => "tutorial Result 2 for elixir",
               "content" => "Category content 2"
             }
           ]
  end

  test "generic action index route with missing required argument returns error" do
    response =
      Domain
      |> get("/search", status: 400)

    assert %{"errors" => errors} = response.resp_body
    assert is_list(errors)
    assert errors != []

    required_error =
      Enum.find(
        errors,
        &(&1["code"] == "required" and &1["detail"] == "is required")
      )

    assert required_error, "Expected to find a 'required' error"

    source_pointer = get_in(required_error, ["source", "pointer"])
    assert source_pointer, "Expected source pointer to be present"

    assert source_pointer == "/query",
           "Expected source pointer '#{source_pointer}' to be /query"
  end

  test "generic GET actions include arguments as query parameters in JSON schema" do
    schema = AshJsonApi.JsonSchema.generate([Domain])

    assert %{
             "method" => "GET",
             "rel" => "route",
             "hrefSchema" => %{
               "properties" => properties,
               "required" => required
             }
           } = Enum.find(schema["links"], &(&1["method"] == "GET" and &1["rel"] == "route"))

    assert Map.has_key?(properties, "query")
    assert Map.has_key?(properties, "category")
    assert "query" in required
  end
end
