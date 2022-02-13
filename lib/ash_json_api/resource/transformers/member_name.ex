defmodule AshJsonApi.Resource.Transformers.MemberName do
  @callback transform_out(type :: String.t()) :: String.t()
  @callback transform_in(type :: String.t()) :: String.t()
end
