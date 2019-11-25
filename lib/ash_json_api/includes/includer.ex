defmodule AshJsonApi.Includes.Includer do
  alias AshJsonApi.Request

  @spec get_includes(record_or_records :: struct | list(struct) | nil, Request.t()) ::
          {struct | list(struct), list(struct)}
  def get_includes(nil, _) do
    {nil, []}
  end

  def get_includes(record_or_records, %Request{includes: includes}) when includes == %{},
    do: {record_or_records, []}

  def get_includes(records, %Request{includes_keyword: includes_keyword})
      when is_list(records) do
    get_includes_list(records, includes_keyword)
  end

  def get_includes(%Ash.DataLayer.Paginator{results: results} = paginator, request) do
    {records, includes} = get_includes(results, request)
    {%{paginator | results: records}, includes}
  end

  def get_includes(record, request) do
    {[record], includes} = get_includes([record], request)

    {record, includes}
  end

  defp get_includes_list(related, []), do: {related, []}

  defp get_includes_list(preloaded, include_keyword) do
    include_keyword
    |> Enum.reduce({preloaded, []}, fn {relationship, further},
                                       {preloaded_without_linkage, includes_list} ->
      {related, further_includes} =
        preloaded
        |> Enum.flat_map(fn record ->
          record
          |> Map.get(relationship, [])
          |> List.wrap()
        end)
        |> get_includes_list(further)

      preloaded_with_linkage =
        Enum.map(
          preloaded_without_linkage,
          &add_linkage(&1, relationship, related)
        )

      {preloaded_with_linkage, [related, further_includes, includes_list]}
    end)
    |> flatten_includes_list()
  end

  defp add_linkage(record, relationship, related) do
    record
    |> Map.put_new(:__linkage__, %{})
    |> Map.update!(:__linkage__, fn linkage ->
      Map.put(linkage, relationship, related)
    end)
  end

  defp flatten_includes_list({related, includes_list}) do
    {related, List.flatten(includes_list)}
  end
end
