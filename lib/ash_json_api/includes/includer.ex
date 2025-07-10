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
            |> List.wrap()
          end)
          |> get_includes_map(further, includes_map)

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

        includes_map =
          if linkage_only? do
            includes_map
          else
            related
            |> List.wrap()
            |> Enum.reduce(includes_map, fn related_item, includes_map ->
              # On construit la clé {type, id}
              type = AshJsonApi.Resource.Info.type(related_item)
              id = AshJsonApi.Resource.encode_primary_key(related_item)

              # On ajoute le record dans includes_map
              case Map.fetch(includes_map, {type, id}) do
                {:ok, _} ->
                  # La clé existe déjà, on merge les linkages
                  Map.update!(includes_map, {type, id}, fn existing ->
                    # On merge les linkages en une liste
                    merge_linkages(existing, related_item)
                  end)

                :error ->
                  # La clé n'existe pas, on l'ajoute avec le linkage, et un linkage vide
                  # si il n'existe pas déjà,
                  Map.put(includes_map, {type, id}, Map.put_new(related_item, :__linkage__, %{}))
              end
            end)
          end

        {preloaded_with_linkage, includes_map}
    end)
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
end
