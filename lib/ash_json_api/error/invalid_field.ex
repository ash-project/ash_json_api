defmodule AshJsonApi.Error.InvalidField do
  @moduledoc """
  Returned when a field is requested that does not exist or is invalid
  """
  @detail @moduledoc

  @type t :: AshJsonApi.Error.t()

  @title "Invalid Field"

  @status_code 400

  use AshJsonApi.Error

  def new(opts) do
    opts
    |> Keyword.put_new(:detail, "Invalid field for type #{opts[:type]}: #{opts[:field]}")
    |> parameter()
    |> Keyword.drop([:type, :field, :parameter?])
    |> super()
  end

  defp parameter(opts) do
    if opts[:parameter?] do
      Keyword.put_new(opts, :source_parameter, "fields[#{opts[:type]}]")
    else
      Keyword.put_new(opts, :source_parameter, "fields")
    end
  end
end
