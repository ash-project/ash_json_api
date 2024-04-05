defmodule AshJsonApi.Error.InvalidQuery do
  @moduledoc """
  Returned when the query provided is invalid
  """
  use Splode.Error, class: :invalid, fields: [:json_xema_error]

  def message(exception) do
    "Invalid body: #{exception.json_xema_error}"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      error.json_xema_error
      |> AshJsonApi.Error.SchemaErrors.all_errors(:json_pointer)
      |> Enum.map(fn %{path: path, message: message} ->
        %AshJsonApi.Error{
          id: Ash.UUID.generate(),
          status_code: 400,
          source_pointer: path,
          code: "invalid_query",
          title: "InvalidQuery",
          detail: message,
          meta: %{}
        }
      end)
    end
  end
end
