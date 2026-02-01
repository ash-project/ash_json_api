# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidFilter do
  @moduledoc """
  Returned when a filter parameter is invalid or malformed
  """

  use Splode.Error,
    class: :invalid,
    fields: [:filter, :detail, :source_parameter]

  def message(error) do
    error.detail
  end

  def exception(opts) do
    filter = opts[:filter]

    detail =
      case filter do
        nil -> "Invalid filter"
        filter -> "Invalid filter: #{filter}"
      end

    opts
    |> Keyword.put_new(:detail, detail)
    |> Keyword.put_new(:source_parameter, "filter")
    |> Keyword.drop([:filter])
    |> super()
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_filter",
        title: "InvalidFilter",
        detail: error.detail,
        source_parameter: error.source_parameter,
        meta: %{}
      }
    end
  end
end
