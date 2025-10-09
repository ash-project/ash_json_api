# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidType do
  @moduledoc """
  Returned when a field is requested for a type that does not exist or is invalid
  """
  use Splode.Error, class: :invalid, fields: [:type]

  def message(error) do
    "No such type: #{error.type}"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_type",
        title: "Invalid Type",
        detail: "No such type #{error.type}",
        source_parameter: "fields[#{error.type}]",
        meta: %{}
      }
    end
  end
end
