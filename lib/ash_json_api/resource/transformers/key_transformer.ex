defmodule AshJsonApi.Resource.Transformers.KeyTransformer do
  @callback convert_from(type :: String.t()) :: String.t()
  @callback convert_to(type :: String.t()) :: String.t()
end
