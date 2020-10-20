defmodule AshJsonApi.Resource.Transformers.RequirePrimaryKey do
  @moduledoc "Ensures that the resource either has a primary key 
    or includes primary_key section from json_api if it has a composite key
  "

  use Ash.Dsl.Transformer
  alias Ash.Dsl.Transformer

  def transform(_resource, dsl) do
    case Transformer.get_option(dsl, [:json_api, :primary_key], :keys) do
      nil ->
        dsl
        |> Transformer.get_entities([:attributes])
        |> Enum.filter(& &1.primary_key?)
        |> Enum.map(& &1.name)
        |> case do
          [_only_one_primary_key] -> {:ok, dsl}
          _ -> raise "AshJsonApi requires primary key when a resource has a composite key"
        end

      keys ->
        attributes = Transformer.get_entities(dsl, [:attributes])

        case Enum.all?(keys, fn key -> Enum.any?(attributes, fn att -> att.name == key end) end) do
          true -> {:ok, dsl}
          false -> raise "AshJsonApi primary keys must be from the resource's attributes"
        end
    end
  end
end
