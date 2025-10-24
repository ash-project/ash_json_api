# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.UnknownError do
  @moduledoc """
  Returned when an unexpected error occurs that doesn't fit other categories
  """

  use Splode.Error,
    class: :unknown,
    fields: [:detail]

  def message(error) do
    error.detail
  end

  def exception(opts) do
    message = opts[:message] || "An unknown error occurred"

    opts
    |> Keyword.put_new(:detail, message)
    |> Keyword.drop([:message])
    |> super()
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 500,
        code: "unknown_error",
        title: "UnknownError",
        detail: error.detail,
        meta: %{}
      }
    end
  end
end
