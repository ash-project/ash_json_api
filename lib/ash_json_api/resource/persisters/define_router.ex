# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Resource.Persisters.DefineRouter do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl) do
    routes = AshJsonApi.Resource.Info.routes(dsl)

    route_matchers =
      routes
      |> Enum.sort(fn left, right ->
        left_path = Path.split(left.route)
        right_path = Path.split(right.route)

        left_path
        |> Enum.zip(right_path)
        |> sorts_first?()
        |> case do
          :undecided ->
            Enum.count(left_path) > Enum.count(right_path)

          result ->
            result
        end
      end)
      |> Enum.map(&route_match/1)

    {:ok,
     Transformer.eval(
       dsl,
       [],
       route_matchers ++
         [
           quote do
             def json_api_match_route(_, _) do
               :error
             end
           end
         ]
     )}
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def route_match(route) do
    split_route = String.split(route.route, "/", trim: true)

    args =
      Enum.map(split_route, fn
        ":" <> param ->
          {String.to_atom(param), [], Elixir}

        param ->
          param
      end)

    params =
      split_route
      |> Enum.filter(&String.starts_with?(&1, ":"))
      |> Enum.map(fn ":" <> param ->
        {param, {String.to_atom(param), [], Elixir}}
      end)

    params = {:%{}, [], params}

    quote do
      def json_api_match_route(unquote(route.method), [unquote_splicing(args)]) do
        {:ok, unquote(Macro.escape(route)), unquote(params)}
      end

      def json_api_match_route(unquote(String.upcase(to_string(route.method))), [
            unquote_splicing(args)
          ]) do
        {:ok, unquote(Macro.escape(route)), unquote(params)}
      end
    end
  end

  defp sorts_first?(zipped) do
    Enum.reduce_while(zipped, :undecided, fn {left_part, right_part}, :undecided ->
      left_param? = String.starts_with?(left_part, ":")
      right_param? = String.starts_with?(right_part, ":")

      cond do
        left_part == right_part ->
          {:cont, :undecided}

        left_param? and not right_param? ->
          {:halt, false}

        not left_param? and right_param? ->
          {:halt, true}

        true ->
          {:cont, :undecided}
      end
    end)
  end
end
