# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Mix.Tasks.AshJsonApi.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  test "installation modifies the mix.exs aliases with alias for getting all routes" do
    test_project()
    |> apply_igniter!()
    |> Igniter.compose_task("ash_json_api.install")
    |> assert_has_patch("mix.exs", """
    30 + |  defp aliases() do
    31 + |    ["phx.routes": ["phx.routes", "ash_json_api.routes"]]
    32 + |  end
    """)
  end
end
