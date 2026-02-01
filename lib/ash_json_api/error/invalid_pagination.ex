# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidPagination do
  @moduledoc """
  Returned when one of the nested parameters provided in the query parameter `page` is invalid
  """

  use Splode.Error, class: :invalid, fields: [:detail]

  def message(error) do
    "Invalid pagination: #{error.detail}"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_pagination",
        title: "InvalidPagination",
        detail: "Invalid pagination: #{error.detail}",
        source_parameter: "page",
        meta: %{}
      }
    end
  end
end
