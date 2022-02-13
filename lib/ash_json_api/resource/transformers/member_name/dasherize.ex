defmodule AshJsonApi.Resource.Transformers.MemberName.Dasherize do
  @behaviour AshJsonApi.Resource.Transformers.MemberName
  @doc """
    Transforms snake case attribute names to dasherized.

    ** Example
    iex> #{__MODULE__}.transform_in("first_name")
    "first-name"
  """
  def transform_in(attribute), do: dasherize(attribute)

  @doc """
    Transforms dasherized attribute names to snake case.

     ** Example
    iex> #{__MODULE__}.transform_out("first-name")
    "first_name"
  """
  def transform_out(attribute), do: underscore(attribute)

  defp dasherize(string, option \\ "-") do
    case Regex.split(~r/(?:^|[-_])|(?=[A-Z])/, to_string(string)) do
      words ->
        words
        |> Enum.filter(&(&1 != ""))
        |> Enum.join(option)
      end
  end

  defp underscore(word) when is_binary(word) do
    word
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.replace(~r/-/, "_")
    |> String.downcase()
  end
end
