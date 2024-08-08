defmodule AshJsonApi.Igniter do
  @moduledoc "Codemods and utilities for working with AshJsonApi & Igniter"

  @doc "Returns the AshJsonApi router containing the domain in question, or a list of all AshJsonApi schemas"
  def find_ash_json_api_router(igniter, domain) do
    {igniter, modules} = ash_json_api_routers(igniter)

    modules
    |> Enum.find(fn module ->
      with {:ok, {_igniter, _source, zipper}} <- Igniter.Code.Module.find_module(igniter, module),
           {:ok, zipper} <- Igniter.Code.Module.move_to_use(zipper, AshJsonApi.Router),
           {:ok, zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 1),
           {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, :domains),
           {:ok, _zipper} <-
             Igniter.Code.List.move_to_list_item(
               zipper,
               &Igniter.Code.Common.nodes_equal?(&1, domain)
             ) do
        true
      else
        _ ->
          false
      end
    end)
    |> case do
      nil ->
        {:error, igniter, modules}

      module ->
        {:ok, igniter, module}
    end
  end

  @doc "Sets up an `AshJsonApi.Router` for AshJsonApi"
  def setup_ash_json_api_router(igniter, ash_phoenix_router_name \\ nil) do
    ash_phoenix_router_name =
      ash_phoenix_router_name || Igniter.Libs.Phoenix.web_module_name("AshJsonApiRouter")

    {igniter, domains} = Ash.Domain.Igniter.list_domains(igniter)

    {igniter, domains} =
      Enum.reduce(domains, {igniter, []}, fn domain, {igniter, list} ->
        case Spark.Igniter.has_extension(
               igniter,
               domain,
               Ash.Domain,
               :extensions,
               AshJsonApi.Domain
             ) do
          {igniter, true} -> {igniter, [domain | list]}
          {igniter, false} -> {igniter, list}
        end
      end)

    domains =
      Enum.map_join(domains, ", ", fn domain ->
        "Module.concat([\"#{inspect(domain)}\"])"
      end)

    igniter
    |> Igniter.Code.Module.find_and_update_or_create_module(
      ash_phoenix_router_name,
      """
      use AshJsonApi.Router,
        domains: [#{domains}],
        open_api: "/open_api"
      """,
      fn zipper ->
        # Should never get here
        {:ok, zipper}
      end
    )
  end

  @doc "Sets up the phoenix module for AshJsonApi"
  def setup_phoenix(igniter, ash_phoenix_router_name \\ nil) do
    ash_phoenix_router_name =
      ash_phoenix_router_name || Igniter.Libs.Phoenix.web_module_name("AshJsonApiRouter")

    case Igniter.Libs.Phoenix.select_router(igniter) do
      {igniter, nil} ->
        igniter
        |> Igniter.add_warning("""
        No Phoenix router found, skipping Phoenix installation.

        See the Getting Started guide for instructions on installing AshJsonApi with `plug`.
        If you have yet to set up Phoenix, you'll have to do that manually and then rerun this installer.
        """)

      {igniter, router} ->
        igniter
        |> update_endpoints(router)
        |> Igniter.Project.Config.configure(
          "config.exs",
          :mime,
          [:extensions],
          %{
            "json" => "application/vnd.api+json"
          },
          updater: fn zipper ->
            Igniter.Code.Map.set_map_key(zipper, "json", "application/vnd.api+json", fn zipper ->
              {:ok, zipper}
            end)
          end
        )
        |> Igniter.Project.Config.configure(
          "config.exs",
          :mime,
          [:types],
          %{
            "application/vnd.api+json" => ["json"]
          },
          updater: fn zipper ->
            Igniter.Code.Map.set_map_key(
              zipper,
              "application/vnd.api+json",
              ["json"],
              fn zipper ->
                zipper =
                  if Igniter.Code.List.list?(zipper) do
                    zipper
                  else
                    Sourceror.Zipper.replace(zipper, [zipper.node])
                  end

                Igniter.Code.List.prepend_new_to_list(zipper, "json")
              end
            )
          end
        )
        |> Igniter.Libs.Phoenix.add_pipeline(:api, "plug :accepts, [\"json\"]",
          router: router,
          warn_on_present?: false
        )
        |> Igniter.Libs.Phoenix.add_scope(
          "/api/json",
          """
          pipe_through [:api]

          forward "/swaggerui",
            OpenApiSpex.Plug.SwaggerUI,
            path: "/api/json/open_api",
            default_model_expand_depth: 4

          forward "/", #{inspect(ash_phoenix_router_name)}
          """,
          router: router
        )
    end
  end

  defp update_endpoints(igniter, router) do
    {igniter, endpoints_that_need_parser} =
      Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)

    Enum.reduce(endpoints_that_need_parser, igniter, fn endpoint, igniter ->
      Igniter.Code.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
        case Igniter.Code.Function.move_to_function_call_in_current_scope(
               zipper,
               :plug,
               2,
               &Igniter.Code.Function.argument_equals?(&1, 0, Plug.Parsers)
             ) do
          {:ok, zipper} ->
            with {:ok, zipper} <- Igniter.Code.Function.move_to_nth_argument(zipper, 1),
                 {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, :parsers),
                 {:ok, zipper} <-
                   Igniter.Code.List.append_new_to_list(zipper, AshJsonApi.Plug.Parser) do
              {:ok, zipper}
            else
              _ ->
                {:warning,
                 "Could not add `AshJsonApi.Plug.Parser` to parsers in endpoint #{endpoint}. Please make this change manually."}
            end

          :error ->
            case parser_location(zipper) do
              {:ok, zipper} ->
                {:ok,
                 Igniter.Code.Common.add_code(zipper, """
                 plug Plug.Parsers,
                   parsers: [:urlencoded, :multipart, :json, AshJsonApi.Plug.Parser],
                   pass: ["*/*"],
                   json_decoder: Jason
                 """)}

              _ ->
                {:warning,
                 "Could not add `AshJsonApi.Plug.Parser` to parsers in endpoint #{endpoint}. Please make this change manually."}
            end
        end
      end)
    end)
  end

  defp parser_location(zipper) do
    with :error <-
           Igniter.Code.Function.move_to_function_call_in_current_scope(
             zipper,
             :plug,
             [1, 2],
             &Igniter.Code.Function.argument_equals?(&1, 0, Plug.Telemetry)
           ),
         :error <-
           Igniter.Code.Function.move_to_function_call_in_current_scope(
             zipper,
             :plug,
             [1, 2]
           ) do
      Igniter.Code.Module.move_to_use(zipper, Phoenix.Endpoint)
      :error
    end
  end

  @doc "Returns all modules that `use AshJsonApi.Router`"
  def ash_json_api_routers(igniter) do
    Igniter.Code.Module.find_all_matching_modules(igniter, fn _name, zipper ->
      match?({:ok, _}, Igniter.Code.Module.move_to_use(zipper, AshJsonApi.Router))
    end)
  end
end
