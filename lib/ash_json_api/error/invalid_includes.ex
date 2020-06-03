defmodule AshJsonApi.Error.InvalidIncludes do
  @moduledoc """
  Returned when the includes string provided in the query parameter `include`
  is invalid.
  """
  @detail @moduledoc

  @type t :: AshJsonApi.Error.t()

  @title "Invalid Includes"

  @status_code 400

  use AshJsonApi.Error

  def new(opts) do
    opts
    |> Keyword.put_new(:parameter, "include")
    |> add_detail()
    |> super()
  end

  defp add_detail(opts) do
    if opts[:includes] do
      Keyword.put_new(opts, :detail, "Invalid includes: #{inspect(opts[:includes])}")
    else
      opts
    end
  end
end
