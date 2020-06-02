defmodule AshJsonApi.Error.InvalidIncludes do
  @detail """
  Returned when the includes string provided in the query parameter `include`
  is invalid.
  """

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
      # TODO: These should be stringified back to the right format, not inspected
      Keyword.put_new(opts, :detail, "Invalid includes: #{inspect(opts[:includes])}")
    else
      opts
    end
  end
end
