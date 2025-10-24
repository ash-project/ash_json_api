# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.ConflictingParams do
  @moduledoc """
  Returned when path parameters and query parameters have conflicting names
  """

  use Splode.Error,
    class: :invalid,
    fields: [:conflicting_keys, :detail]

  def message(error) do
    error.detail
  end

  def exception(opts) do
    opts
    |> Keyword.put_new(:detail, "conflict path and query params")
    |> Keyword.drop([:conflicting_keys])
    |> super()
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_query",
        title: "InvalidQuery",
        detail: error.detail,
        meta: %{}
      }
    end
  end
end
