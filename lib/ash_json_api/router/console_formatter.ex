# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Router.ConsoleFormatter do
  @moduledoc false

  @doc """
  Format the routes for printing.

  This was copied from Phoenix and adapted for our case.
  """
  def format(router, json_router, endpoint \\ nil) do
    routes = Phoenix.Router.routes(router)
    column_widths = calculate_column_widths(router, routes, endpoint)

    routes
    |> Enum.map(&format_route(&1, router, json_router, column_widths))
    |> Enum.filter(& &1)
    |> Enum.join("")
  end

  defp calculate_column_widths(router, routes, endpoint) do
    sockets = (endpoint && endpoint.__sockets__()) || []

    widths =
      Enum.reduce(routes, {0, 0, 0}, fn route, acc ->
        %{verb: verb, path: path, helper: helper} = route
        verb = verb_name(verb)
        {verb_len, path_len, route_name_len} = acc
        route_name = route_name(router, helper)

        {max(verb_len, String.length(verb)), max(path_len, String.length(path)),
         max(route_name_len, String.length(route_name))}
      end)

    Enum.reduce(sockets, widths, fn {path, _mod, _opts}, acc ->
      {verb_len, path_len, route_name_len} = acc
      prefix = if router.__helpers__(), do: "websocket", else: ""

      {verb_len, max(path_len, String.length(path <> "/websocket")),
       max(route_name_len, String.length(prefix))}
    end)
  end

  defp format_route(
         %{
           verb: _verb,
           path: path,
           plug: json_router,
           helper: helper
         },
         router,
         json_router,
         _column_widths
       ) do
    routes =
      json_router.domains()
      |> Enum.map(&AshJsonApi.Domain.Info.routes(&1))
      |> List.flatten()

    column_widths =
      Enum.reduce(routes, {0, 0, 0}, fn route, acc ->
        %{method: method, route: sub_path} = route
        {verb_len, path_len, route_name_len} = acc
        verb = verb_name(method)
        path = path <> sub_path
        route_name = route_name(router, helper)

        {max(verb_len, String.length(verb)), max(path_len, String.length(path)),
         max(route_name_len, String.length(route_name))}
      end)

    Enum.map(routes, fn route ->
      verb = verb_name(route.method)
      route_name = route_name(router, helper)
      {verb_len, path_len, route_name_len} = column_widths
      log_module = route.__struct__

      String.pad_leading(route_name, route_name_len) <>
        "  " <>
        String.pad_trailing(verb, verb_len) <>
        "  " <>
        String.pad_trailing(path <> route.route, path_len) <>
        "  " <>
        "#{inspect(log_module)} :#{route.type}\n"
    end)
  end

  defp format_route(_route, _router, _json_router, _) do
    nil
  end

  defp route_name(_router, nil), do: ""

  defp route_name(router, name) do
    if router.__helpers__() do
      name <> "_path"
    else
      ""
    end
  end

  defp verb_name(verb), do: verb |> to_string() |> String.upcase()
end
