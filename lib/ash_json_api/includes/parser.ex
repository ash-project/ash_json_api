defmodule AshJsonApi.Includes.Parser do
  @moduledoc false

  defstruct [:allowed, :disallowed]

  def parse_and_validate_includes(resource, %{"include" => include_string}) do
    allowed = allowed_preloads(resource)

    include_string
    |> String.split(",")
    |> Stream.map(&String.split(&1, "."))
    |> Stream.map(fn include ->
      {include, get_in(allowed, include) || false}
    end)
    |> Enum.reduce(%__MODULE__{allowed: [], disallowed: []}, fn {include, allowed?}, acc ->
      if allowed? do
        Map.update!(acc, :allowed, fn list -> [include | list] end)
      else
        Map.update!(acc, :disallowed, fn list -> [include | list] end)
      end
    end)
  end

  def parse_and_validate_includes(_, _), do: %__MODULE__{allowed: [], disallowed: []}

  defp allowed_preloads(resource) do
    resource
    |> AshJsonApi.Resource.Info.includes()
    |> to_nested_map()
  end

  # defp to_nested_map([]), do: true

  defp to_nested_map(list) when is_list(list) do
    list
    |> Enum.map(fn
      {key, value} when is_list(value) -> {to_string(key), to_nested_map(value)}
      {key, value} when is_atom(value) -> {to_string(key), to_nested_map([value])}
      value -> {to_string(value), to_nested_map(value)}
    end)
    |> Enum.into(%{})
  end

  defp to_nested_map(true), do: true
  defp to_nested_map(value), do: %{value => true}
end
