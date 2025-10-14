# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidBody do
  @moduledoc """
  Returned when the request body provided is invalid
  """

  use Splode.Error, class: :invalid, fields: [:json_xema_error]

  def message(exception) do
    "Invalid body: #{exception.json_xema_error}"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      error.json_xema_error
      |> AshJsonApi.Error.SchemaErrors.all_errors(:json_pointer)
      |> Enum.map(fn error_map ->
        # Use specific code and title if provided (e.g., for required errors)
        code = Map.get(error_map, :code, "invalid_body")
        title = Map.get(error_map, :title, "InvalidBody")

        %AshJsonApi.Error{
          id: Ash.UUID.generate(),
          status_code: 400,
          source_pointer: error_map.path,
          code: code,
          title: title,
          detail: error_map.message,
          meta: %{}
        }
      end)
    end
  end
end
