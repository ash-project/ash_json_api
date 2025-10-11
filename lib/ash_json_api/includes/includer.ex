# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

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
    {records, includes_map} = get_includes_map(records, includes_keyword)
    {records, Map.values(includes_map)}
  end

  def get_includes(%{results: results} = paginator, request) do
    {records, includes} = get_includes(results, request)
    {%{paginator | results: records}, includes}
  end

  def get_includes(record, request) do
    {[record], includes} = get_includes([record], request)

    {record, includes}
  end

  defp get_includes_map(preloaded, includes_keyword, includes_map \\ %{})
  defp get_includes_map(related, [], includes_map), do: {related, includes_map}

  defp get_includes_map(preloaded, %Ash.Query{load: load}, includes_map),
    do: get_includes_map(preloaded, load, includes_map)

  defp get_includes_map(preloaded, includes_keyword, includes_map) do
    includes_keyword
    |> Enum.reduce({preloaded, includes_map}, fn
      {relationship, further}, {preloaded_without_linkage, includes_map} ->
        linkage_only? =
          case further do
            %{__linkage_only__: true} -> true
            _ -> false
          end

        {related, includes_map} =
          preloaded
          |> Enum.flat_map(fn record ->
            record
            |> Map.get(relationship, [])
            |> extract_records_from_relationship()
          end)
          |> get_includes_map(further, includes_map)

        preloaded_with_linkage =
          Enum.map(
            preloaded_without_linkage,
            fn record ->
              relationship_value = Map.get(record, relationship, [])
              related = extract_records_from_relationship(relationship_value)

              # Store both the extracted records and the original value (which might be a Page)
              record
              |> add_linkage(relationship, related)
              |> add_page_info(relationship, relationship_value)
            end
          )

        includes_map =
          if linkage_only? do
            includes_map
          else
            related
            |> List.wrap()
            |> Enum.reduce(includes_map, fn related_item, includes_map ->
              type = AshJsonApi.Resource.Info.type(related_item)
              id = AshJsonApi.Resource.encode_primary_key(related_item)

              case Map.fetch(includes_map, {type, id}) do
                {:ok, _} ->
                  Map.update!(includes_map, {type, id}, fn existing ->
                    merge_linkages(existing, related_item)
                  end)

                :error ->
                  Map.put(includes_map, {type, id}, Map.put_new(related_item, :__linkage__, %{}))
              end
            end)
          end

        {preloaded_with_linkage, includes_map}
    end)
  end

  # Extract records from relationship value, handling both plain lists and Page structs
  defp extract_records_from_relationship(%{__struct__: struct, results: results})
       when struct in [Ash.Page.Offset, Ash.Page.Keyset] do
    List.wrap(results)
  end

  defp extract_records_from_relationship(value) do
    List.wrap(value)
  end

  defp add_linkage(record, relationship, related) do
    record
    |> Map.put_new(:__linkage__, %{})
    |> Map.update!(:__linkage__, fn linkage ->
      Map.put(linkage, relationship, related)
    end)
  end

  # Store pagination info for relationships that were paginated
  defp add_page_info(record, relationship, %{__struct__: struct} = page)
       when struct in [Ash.Page.Offset, Ash.Page.Keyset] do
    record
    |> Map.put_new(:__pagination__, %{})
    |> Map.update!(:__pagination__, fn pagination_info ->
      Map.put(pagination_info, relationship, page)
    end)
  end

  defp add_page_info(record, _relationship, _value), do: record

  defp merge_linkages(record, to_merge) do
    linkage_to_merge = Map.get(to_merge, :__linkage__, %{})

    record
    |> Map.update!(:__linkage__, fn linkage ->
      Map.merge(linkage, linkage_to_merge, fn _key, a, b ->
        a ++ b
      end)
    end)
  end
end
