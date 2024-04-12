if Code.ensure_loaded?(OpenApiSpex) do
  defmodule AshJSonApi.OpenApiSpexChecker do
    @moduledoc false
    @doc false
    def has_open_api?, do: true
  end
else
  defmodule AshJSonApi.OpenApiSpexChecker do
    @moduledoc false

    @doc false
    def has_open_api?, do: false
  end
end
