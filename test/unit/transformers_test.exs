defmodule AshJsonApi.ResourceTest do
  use ExUnit.Case
  doctest AshJsonApi.Resource.Transformers.KeyTransformer.Dasherize
  doctest AshJsonApi.Resource.Transformers.KeyTransformer.CamelCase
end
