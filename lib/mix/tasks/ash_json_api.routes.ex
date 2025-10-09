# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.AshJsonApi.Routes do
  use Mix.Task

  require Logger
  alias AshJsonApi.Router.ConsoleFormatter

  @moduledoc """
  Prints all routes pertaining to AshJsonApi.Router for the default or a given router.

  This task can be called directly, accepting the same options as `mix phx.routes`, except for `--info`.

  Accepts option `--json_router` to specify your Ash Json Router. Defaults to `YourAppWeb.AshJsonApiRouter`.

  Alternatively, you can modify your aliases task to run them back to back it.

  ```elixir
  aliases: ["phx.routes": ["do", "phx.routes,", "ash_json_api.routes"]]
  ```
  """

  @shortdoc "Prints all routes by AshJsonApiRouter"
  @impl true
  def run(args, base \\ Mix.Phoenix.base()) do
    if Code.ensure_loaded?(Phoenix.Router) &&
         function_exported?(Phoenix.Router, :__formatted_routes__, 1) do
      raise """
      AshJsonApi routes are now included in `mix phx.routes` automatically.
      There is no need to use this task or include it in your aliases.

      Remove: `ash_json_api.routes`
      """
    end

    Mix.Task.run("compile", args)
    Mix.Task.reenable("ash_json_api.routes")

    {opts, args, _} =
      OptionParser.parse(args,
        switches: [endpoint: :string, router: :string, json_router: :string]
      )

    {router_mod, json_router_mod, endpoint_mod} =
      case args do
        [passed_router] ->
          {router(passed_router, base), json_router(opts[:json_router], base), opts[:endpoint]}

        [] ->
          {router(opts[:router], base), json_router(opts[:json_router], base),
           endpoint(opts[:endpoint], base)}
      end

    case Keyword.fetch(opts, :info) do
      {:ok, url} ->
        get_url_info(url, {router_mod, opts})

      :error ->
        router_mod
        |> ConsoleFormatter.format(json_router_mod, endpoint_mod)
        |> Mix.shell().info()
    end
  end

  defp router(nil, base) do
    if Mix.Project.umbrella?() do
      Mix.raise("""
      umbrella applications require an explicit router to be given to phx.routes, for example:

          $ mix ash_json_api.routes MyAppWeb.Router

      An alias can be added to mix.exs aliases to automate this:

          "ash_json_api.routes": "ash_json_api.routes MyAppWeb.Router"

      """)
    end

    web_router = web_mod(base, "Router")
    old_router = app_mod(base, "Router")

    loaded(web_router) || loaded(old_router) ||
      Mix.raise("""
      no router found at #{inspect(web_router)} or #{inspect(old_router)}.
      An explicit router module may be given to ash_json_api.routes, for example:

          $ mix ash_json_api.routes MyAppWeb.Router

      An alias can be added to mix.exs aliases to automate this:

          "ash_json_api.routes": "ash_json_api.routes MyAppWeb.Router"

      """)
  end

  defp router(router_name, _base) do
    arg_router = Module.concat([router_name])
    loaded(arg_router) || Mix.raise("the provided router, #{inspect(arg_router)}, does not exist")
  end

  defp json_router(nil, base) do
    loaded(web_mod(base, "AshJsonApiRouter"))
  end

  defp json_router(module, _base) do
    loaded(web_mod([module], "AshJsonApiRouter"))
  end

  defp endpoint(nil, base) do
    loaded(web_mod(base, "Endpoint"))
  end

  defp endpoint(module, _base) do
    loaded(Module.concat([module]))
  end

  defp app_mod(base, name), do: Module.concat([base, name])

  defp web_mod(base, name), do: Module.concat(["#{base}Web", name])

  defp loaded(module) do
    if Code.ensure_loaded?(module), do: module
  end

  def get_url_info(url, {router_mod, _opts}) do
    %{path: path} = URI.parse(url)

    meta = Phoenix.Router.route_info(router_mod, "GET", path, "")
    %{plug: plug, plug_opts: plug_opts} = meta

    {module, func_name} =
      if log_mod = meta[:log_module] do
        {log_mod, meta[:log_function]}
      else
        {plug, plug_opts}
      end

    Mix.shell().info("Module: #{inspect(module)}")
    if func_name, do: Mix.shell().info("Function: #{inspect(func_name)}")

    file_path = get_file_path(module)

    if line = get_line_number(module, func_name) do
      Mix.shell().info("#{file_path}:#{line}")
    else
      Mix.shell().info("#{file_path}")
    end
  end

  defp get_file_path(module_name) do
    [compile_infos] = Keyword.get_values(module_name.module_info(), :compile)
    [source] = Keyword.get_values(compile_infos, :source)
    source
  end

  defp get_line_number(_, nil), do: nil

  defp get_line_number(module, function_name) do
    {_, _, _, _, _, _, functions_list} = Code.fetch_docs(module)

    function_infos =
      functions_list
      |> Enum.find(fn {{type, name, _}, _, _, _, _} ->
        type == :function and name == function_name
      end)

    case function_infos do
      {_, line, _, _, _} -> line
      nil -> nil
    end
  end
end
