defmodule Test.Acceptance.RouteTest do
  use ExUnit.Case, async: true

  defmodule Actions do
    use Ash.Resource,
      domain: Test.Acceptance.RouteTest.Domain,
      extensions: [AshJsonApi.Resource]

    json_api do
      routes do
        route(:get, "/say_hello/:to", :say_hello)
      end
    end

    actions do
      action :say_hello, :string do
        argument(:to, :string, allow_nil?: false)

        run(fn input, _ ->
          {:ok, "Hello, #{input.arguments.to}!"}
        end)
      end
    end
  end

  defmodule Domain do
    use Ash.Domain,
      extensions: [
        AshJsonApi.Domain
      ]

    json_api do
      router(Test.Acceptance.RouteTest.Router)
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

  test "generic actions can be called" do
    assert Domain
           |> get("/say_hello/fred", status: 200)
           |> Map.get(:resp_body)
           |> Kernel.==("Hello, fred!")
  end
end
