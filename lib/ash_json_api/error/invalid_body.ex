defmodule AshJsonApi.Error.InvalidBody do
  @detail """
  Returned when the request body provided is invalid
  """
  @title "Invalid Body"
  @status_code 400

  use AshJsonApi.Error

  def new(opts) do
    json_xema_error = opts[:json_xema_error]

    opts_without_error = Keyword.delete(opts, :json_xema_error)

    json_xema_error
    |> AshJsonApi.Error.SchemaErrors.all_errors(:json_pointer)
    |> Enum.map(fn %{path: path, message: message} ->
      opts_without_error
      |> Keyword.put(:detail, message)
      |> Keyword.put(:source_pointer, path)
      |> super()
    end)
  end
end
