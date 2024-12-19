if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshJsonApi.Install do
    @moduledoc "Installs AshJsonApi. Should be run with `mix igniter.install ash_json_api`"
    @shortdoc @moduledoc
    require Igniter.Code.Common
    use Igniter.Mix.Task

    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        adds_deps: [{:open_api_spex, "~> 3.0"}]
      }
    end

    def igniter(igniter, _argv) do
      ash_phoenix_router_name = Igniter.Libs.Phoenix.web_module_name(igniter, "AshJsonApiRouter")

      igniter =
        igniter
        |> Igniter.Project.Formatter.import_dep(:ash_json_api)
        |> Spark.Igniter.prepend_to_section_order(:"Ash.Resource", [:json_api])
        |> Spark.Igniter.prepend_to_section_order(:"Ash.Domain", [:json_api])

      {igniter, candidate_ash_json_api_routers} =
        AshJsonApi.Igniter.ash_json_api_routers(igniter)

      if Enum.empty?(candidate_ash_json_api_routers) do
        igniter
        |> AshJsonApi.Igniter.setup_ash_json_api_router(ash_phoenix_router_name)
        |> AshJsonApi.Igniter.setup_phoenix(ash_phoenix_router_name)
      else
        igniter
        |> Igniter.add_warning("AshJsonApi router already exists, skipping installation.")
      end
    end
  end
else
  defmodule Mix.Tasks.Ash.Install do
    @moduledoc "Installs AshJsonApi. Should be run with `mix igniter.install ash_json_api`"
    @shortdoc @moduledoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_json_api.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
