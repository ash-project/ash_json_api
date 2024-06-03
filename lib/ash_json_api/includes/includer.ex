defmodule AshJsonApi.Includes.Includer do
  @moduledoc false
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

  def get_includes(%{results: results} = paginator, request) do
    {records, includes} = get_includes(results, request)
    {%{paginator | results: records}, includes}
  end

  def get_includes(record, request) do
    {[record], includes} = get_includes([record], request)

    {record, includes}
  end

  defp get_includes_list(related, []), do: {related, []}

  defp get_includes_list(preloaded, %Ash.Query{load: load}),
    do: get_includes_list(preloaded, load)

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
          fn record ->
            related =
              record
              |> Map.get(relationship, [])
              |> List.wrap()

            add_linkage(record, relationship, related)
          end
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

  defp merge_linkages(record, to_merge) do
    linkage_to_merge = Map.get(to_merge, :__linkage__, %{})

    record
    |> Map.update!(:__linkage__, fn linkage ->
      Map.merge(linkage, linkage_to_merge, fn _key, a, b ->
        a ++ b
      end)
    end)
  end

  defp flatten_includes_list({related, includes_list}) do
    includes =
      includes_list
      |> List.flatten()
      |> Enum.reduce(%{}, fn include, map ->
        type = AshJsonApi.Resource.Info.type(include)
        id = AshJsonApi.Resource.encode_primary_key(include)

        case Map.fetch(map, {type, id}) do
          {:ok, _} ->
            Map.update!(map, {type, id}, fn existing ->
              merge_linkages(existing, include)
            end)

          :error ->
            Map.put(map, {type, id}, include)
        end
      end)
      |> Map.values()

    {related, includes}
  end
end
