# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.Acceptance.RouteTest do
  use ExUnit.Case, async: true

  defmodule Actions do
    use Ash.Resource,
      domain: Test.Acceptance.RouteTest.Domain,
      extensions: [AshJsonApi.Resource]

    json_api do
      routes do
        route(:get, "/say_hello/:to", :say_hello)
        route(:get, "/say_hello", :say_hello, query_params: [:to])
        route(:post, "/required_say_hello/:to", :with_required)
        route(:post, "/trigger_job", :trigger_job)
      end
    end

    actions do
      action :say_hello, :string do
        argument(:to, :string, allow_nil?: false)

        run(fn input, _ ->
          {:ok, "Hello, #{input.arguments.to}!"}
        end)
      end

      action :with_required, :string do
        argument(:to, :string, allow_nil?: false)
        argument(:from, :string, allow_nil?: false)

        run(fn input, _ ->
          {:ok, "Hello, #{input.arguments.to}, from: #{input.arguments.from}!"}
        end)
      end

      action :trigger_job do
        run(fn _input, _ ->
          :ok
        end)
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
    end

    resources do
      resource(Actions)
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

  test "generic actions can be called" do
    assert Domain
           |> get("/say_hello/fred", status: 200)
           |> Map.get(:resp_body)
           |> Kernel.==("Hello, fred!")
  end

  test "generic actions can be called with query params" do
    assert Domain
           |> get("/say_hello?to=fred", status: 200)
           |> Map.get(:resp_body)
           |> Kernel.==("Hello, fred!")
  end

  test "generic actions with no return can be called" do
    assert Domain
           |> post("/trigger_job", %{}, status: 201)
           |> Map.get(:resp_body)
           |> Kernel.==(%{"success" => true})
  end

  test "generic actions with required inputs" do
    assert Domain
           |> post(
             "/required_say_hello/fred",
             %{
               data: %{
                 from: "joe"
               }
             },
             status: 201
           )
           |> Map.get(:resp_body)
  end

  test "generic actions with missing required arguments should include field name in source pointer" do
    response =
      Domain
      |> post(
        "/required_say_hello/fred",
        %{
          data: %{
            from: ""
          }
        },
        status: 400
      )

    assert %{"errors" => errors} = response.resp_body
    assert is_list(errors)
    assert errors != []

    # Find the "required" error for the missing "from" argument
    required_error = Enum.find(errors, &(&1["code"] == "required"))
    assert required_error, "Expected to find a 'required' error"

    # The source pointer should include the field name that's missing
    source_pointer = get_in(required_error, ["source", "pointer"])
    assert source_pointer, "Expected source pointer to be present"

    assert String.contains?(source_pointer, "from"),
           "Expected source pointer '#{source_pointer}' to contain field name 'from'"
  end

  test "conflict path and query params should return proper JSON API error" do
    # This triggers the "conflict path and query params" string error
    # by having both a path param (:to) and query param (?to=) with the same name
    response =
      Domain
      |> get("/say_hello/fred?to=john", status: 400)

    assert %{"errors" => errors} = response.resp_body
    assert is_list(errors)
    assert errors != []

    # Find the conflict error
    conflict_error = Enum.find(errors, &(&1["code"] == "invalid_query"))
    assert conflict_error, "Expected to find an 'invalid_query' error"

    # Verify the error details
    assert conflict_error["title"] == "InvalidQuery"
    assert conflict_error["detail"] == "conflict path and query params"
    assert conflict_error["status"] == "400"
    assert is_binary(conflict_error["id"])
  end
end
