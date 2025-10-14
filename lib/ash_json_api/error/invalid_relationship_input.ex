# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidRelationshipInput do
  @moduledoc """
  Returned when the request body provided is invalid
  """

  use Splode.Error, class: :invalid, fields: [:relationship, :input]

  def message(exception) do
    "Invalid relationship input for #{exception.relationship}: #{Jason.encode!(exception.input)}"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        source_pointer: "/data/relationships/#{error.relationship}",
        code: "invalid_body",
        title: "InvalidBody",
        detail: "invalid relationship input",
        meta: %{}
      }
    end
  end
end
