defmodule AshJsonApi.Resource.Transformers.RequirePrimaryKey do
  @moduledoc "Ensures that the resource either has a primary key 
    or includes primary_key section from json_api if it has a composite key
  "

  use Ash.Dsl.Transformer
  alias Ash.Dsl.Transformer

  def transform(resource, dsl) do
    case Transformer.get_option(dsl, [:json_api, :primary_key], :keys) do
      nil ->
        case Ash.Resource.primary_key(resource) do
          [_only_one_primary_key] ->
            {:ok, dsl}

          _ ->
            raise Ash.Error.Dsl.DslError,
              module: __MODULE__,
              path: [:json_api, :primary_key],
              message: "AshJsonApi requires primary key when a resource has a composite key"
        end

      keys ->
        dsl
        |> Transformer.get_entities([:attributes])
        |> contains_all(keys)
        |> case do
          true ->
            {:ok, dsl}

          false ->
            raise Ash.Error.Dsl.DslError,
              module: __MODULE__,
              path: [:json_api, :primary_key],
              message: "AshJsonApi primary key must be from the resource's attributes"
        end
    end
  end

  defp contains_all(attributes, keys) do
    Enum.all?(keys, fn key ->
      Enum.any?(attributes, &(&1.name == key))
    end)
  end

  def after?(Ash.Resource.Transformers.CachePrimaryKey = _), do: true
  def after?(_), do: false
end
