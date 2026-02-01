# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.MissingSchema do
  @moduledoc """
  Returned when a required schema is not found for validation
  """

  use Splode.Error,
    class: :invalid,
    fields: [:detail]

  def message(error) do
    error.detail
  end

  def exception(opts) do
    opts
    |> Keyword.put_new(:detail, "No schema found for validation")
    |> super()
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "missing_schema",
        title: "MissingSchema",
        detail: error.detail,
        meta: %{}
      }
    end
  end
end
