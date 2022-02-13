defmodule AshJsonApi.ResourceTest do
  use ExUnit.Case
  doctest AshJsonApi.Resource.Transformers.MemberName.Dasherize
  doctest AshJsonApi.Resource.Transformers.MemberName.CamelCase
end
