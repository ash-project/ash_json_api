# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Type do
  @moduledoc """
  The behaviour for customizing how a datatype is rendered and written in AshJsonApi.
  """

  @callback json_schema(Keyword.t()) :: map
  @callback json_write_schema(Keyword.t()) :: map

  @optional_callbacks json_schema: 1

  defmacro __using__(_) do
    quote do
      @behaviour AshJsonApi.Type

      def json_write_schema(constraints), do: json_schema(constraints)

      defoverridable json_write_schema: 1
    end
  end
end
