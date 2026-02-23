# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.MissingTypeOnCreate do
  @moduledoc """
  Returned when a POST create request has a data object but no type member,
  and the domain has require_type_on_create? enabled (JSON:API spec compliance).
  """
  use Splode.Error, class: :invalid, fields: []

  def message(_error) do
    "The resource object MUST contain at least a type member."
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(_error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "missing_type",
        title: "Invalid resource object",
        detail: "The resource object MUST contain at least a type member.",
        source_pointer: "/data",
        meta: %{}
      }
    end
  end
end
