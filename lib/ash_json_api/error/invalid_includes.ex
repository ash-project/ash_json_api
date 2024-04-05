defmodule AshJsonApi.Error.InvalidIncludes do
  @moduledoc """
  Returned when the includes string provided in the query parameter `include`
  is invalid.
  """
  use Splode.Error, class: :invalid, fields: [:includes]

  @type t() :: %__MODULE__{}

  def message(error) do
    "Invalid includes: #{inspect(error.includes)}"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_includes",
        title: "Invalid Includes",
        detail: "Invalid includes: #{inspect(error.includes)}",
        source_parameter: "include",
        meta: %{}
      }
    end
  end
end
