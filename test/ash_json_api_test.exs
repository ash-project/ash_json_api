defmodule AshJsonApiTest do
  use ExUnit.Case
  doctest AshJsonApi

  test "greets the world" do
    assert AshJsonApi.hello() == :world
  end
end
