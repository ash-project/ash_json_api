# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(OpenApiSpex) do
  defmodule AshJsonApi.OpenApiSpexChecker do
    @moduledoc false
    @doc false
    def has_open_api?, do: true
  end
else
  defmodule AshJsonApi.OpenApiSpexChecker do
    @moduledoc false

    @doc false
    def has_open_api?, do: false
  end
end
