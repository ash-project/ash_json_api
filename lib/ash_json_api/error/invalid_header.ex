defmodule AshJsonApi.Error.InvalidHeader do
  @moduledoc """
  Returned when a header provided is invalid
  """

  @detail @moduledoc
  @title "Invalid Header"
  @status_code 400

  use AshJsonApi.Error

  alias AshJsonApi.Error.SchemaErrors

  def new(opts) do
    json_xema_error = opts[:json_xema_error]

    opts_without_error = Keyword.delete(opts, :json_xema_error)

    json_xema_error
    |> SchemaErrors.all_errors()
    |> Enum.map(fn %{path: path, message: message} ->
      opts_without_error
      |> Keyword.put(:detail, message)
      |> Keyword.put(:source_parameter, path)
      |> super()
    end)
  end
end
