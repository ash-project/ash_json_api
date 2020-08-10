defmodule AshJsonApi.Error.InvalidType do
  @moduledoc """
  Returned when a field is requested for a type that does not exist or is invalid
  """
  @detail @moduledoc

  @type t :: AshJsonApi.Error.t()

  @title "Invalid Type"

  @status_code 400

  use AshJsonApi.Error

  def new(opts) do
    opts
    |> Keyword.put_new(:source_parameter, "fields[#{opts[:type]}]")
    |> Keyword.put_new(:detail, "No such type #{opts[:type]}")
    |> Keyword.delete(:type)
    |> super()
  end
end
