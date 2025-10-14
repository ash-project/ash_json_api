# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Resource.Transformers.ValidateNoOverlappingRoutes do
  @moduledoc false
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl) do
    dsl
    |> Transformer.get_entities([:json_api, :routes])
    |> Enum.group_by(fn route ->
      {route.method, route.route}
    end)
    |> Enum.reduce_while({:ok, dsl}, fn {{method, route}, group}, {:ok, dsl} ->
      case group do
        [_route] ->
          {:cont, {:ok, dsl}}

        _ ->
          {:halt, {:error, "Duplicate routes defined for #{method}: #{route}"}}
      end
    end)
  end
end
