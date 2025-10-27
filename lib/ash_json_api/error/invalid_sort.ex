# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidSort do
  @moduledoc """
  Returned when a sort parameter is invalid or malformed
  """

  use Splode.Error,
    class: :invalid,
    fields: [:sort, :field, :detail, :source_parameter]

  def message(error) do
    error.detail
  end

  def exception(opts) do
    sort = opts[:sort]
    field = opts[:field]

    detail =
      cond do
        field -> "Invalid sort field: #{field}"
        sort -> "Invalid sort: #{sort}"
        true -> "Invalid sort parameter"
      end

    opts
    |> Keyword.put_new(:detail, detail)
    |> Keyword.put_new(:source_parameter, "sort")
    |> Keyword.drop([:sort, :field])
    |> super()
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_sort",
        title: "InvalidSort",
        detail: error.detail,
        source_parameter: error.source_parameter,
        meta: %{}
      }
    end
  end
end
