defmodule AshJsonApi.Error.InvalidQuery do
  @moduledoc """
  Returned when the query provided is invalid
  """
  @detail @moduledoc
  @title "Invalid Query"
  @status_code 400

  use AshJsonApi.Error

  def new(opts) do
    json_xema_error = opts[:json_xema_error]

    opts_without_error = Keyword.delete(opts, :json_xema_error)

    json_xema_error
    |> AshJsonApi.Error.SchemaErrors.all_errors()
    |> Enum.map(fn %{path: path, message: message} ->
      opts_without_error
      |> Keyword.put(:detail, message)
      |> Keyword.put(:source_parameter, path)
      |> super()
    end)
  end
end
