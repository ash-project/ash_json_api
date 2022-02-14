defmodule AshJsonApi.Resource.Transformers.KeyTransformer.CamelCase do
  @behaviour AshJsonApi.Resource.Transformers.KeyTransformer
    @doc """
    Transforms snake case attribute names to camelCase.

    iex> #{__MODULE__}.transform_in("first_name")
    "firstName"
  """
  def convert_to(attribute), do: camelize(attribute)

    @doc """
    Transforms snake case attribute names to camelCase.

    iex> #{__MODULE__}.transform_out("firstName")
    "first_name"
  """
  def convert_from(attribute), do: underscore(attribute)

  defp camelize(word, option \\ :lower) do
    case Regex.split(~r/(?:^|[-_])|(?=[A-Z])/, to_string(word)) do
      words ->
        words
        |> Enum.filter(&(&1 != ""))
        |> camelize_list(option)
        |> Enum.join()
    end
  end

  defp camelize_list([], _), do: []

  defp camelize_list([h | tail], :upper) do
    [capitalize(h)] ++ camelize_list(tail, :upper)
  end

  defp camelize_list([h | tail], :lower) do
    [lowercase(h)] ++ camelize_list(tail, :upper)
  end

  defp capitalize(word), do: String.capitalize(word)
  defp lowercase(word), do: String.downcase(word)

  defp underscore(word) when is_binary(word) do
    word
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.replace(~r/-/, "_")
    |> String.downcase()
  end
end
