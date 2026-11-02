# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.OptionalOpenApiSpexTest do
  @moduledoc """
  `open_api_spex` is an optional dependency, and the modules below are only compiled when it
  is present. The test suite always has it, so a call into one of them from anywhere else
  compiles here but raises `UndefinedFunctionError` in apps without it. This checks the
  compiled code for such calls.
  """
  use ExUnit.Case, async: true

  @guarded_modules [AshJsonApi.OpenApi, AshJsonApi.Controllers.OpenApi]

  test "modules that are always compiled do not call code that requires open_api_spex" do
    {:ok, modules} = :application.get_key(:ash_json_api, :modules)

    offending_calls =
      for module <- modules,
          module not in @guarded_modules,
          {:ok, {^module, [imports: imports]}} = :beam_lib.chunks(:code.which(module), [:imports]),
          {called, _function, _arity} = call <- imports,
          requires_open_api_spex?(called) do
        {module, call}
      end

    assert offending_calls == []
  end

  defp requires_open_api_spex?(module) do
    module == AshJsonApi.OpenApi or
      String.starts_with?(inspect(module), "OpenApiSpex")
  end
end
