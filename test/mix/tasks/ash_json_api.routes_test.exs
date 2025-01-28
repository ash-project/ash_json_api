Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule AshJsonApiWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/json" do
    pipe_through([:api])

    forward("/test/", AshJsonApiWeb.AshJsonApiRouter)
  end
end

defmodule AshJsonApiWeb.AshJsonApiRouter do
  use AshJsonApi.Router, domains: [Test.Domain], prefix: "/api/json"
end

defmodule Test.Domain do
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/tickets", Test.Ticket do
        index :read
        get :read
      end
    end
  end
end

defmodule Test.Ticket do
  use Ash.Resource, extensions: [AshJsonApi.Resource], domain: nil

  json_api do
    type "ticket"

    routes do
      base "/tickets"
      index :read
    end
  end

  resource do
    require_primary_key?(false)
  end

  actions do
    defaults([:read])
  end
end

defmodule Mix.Tasks.AshJsonApi.RoutesTest do
  use ExUnit.Case

  test "prints json api routes" do
    Mix.Tasks.AshJsonApi.Routes.run(["--no-compile"])
    assert_receive {:mix_shell, :info, [routes]}

    assert routes =~ """
             GET  /api/json/test/tickets      AshJsonApi.Resource.Route :index
             GET  /api/json/test/tickets/:id  AshJsonApi.Resource.Route :get
           """
  end

  test "prints json api routes with specified json router" do
    Mix.Tasks.AshJsonApi.Routes.run([
      "--json_router AshJsonApiWeb.AshJsonApiRouter",
      "--no-compile"
    ])

    assert_receive {:mix_shell, :info, [routes]}

    assert routes =~ """
             GET  /api/json/test/tickets      AshJsonApi.Resource.Route :index
             GET  /api/json/test/tickets/:id  AshJsonApi.Resource.Route :get
           """
  end
end
