# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.NotFound do
  @moduledoc """
  Returned when a record was explicitly requested, but could not be found.
  """

  use Splode.Error, class: :invalid, fields: [:filter, :resource]

  def message(error) do
    "No #{AshJsonApi.Resource.Info.type(error.resource)} record found with `#{inspect(error.filter)}`"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 404,
        code: "not_found",
        title: "Entity Not Found",
        detail: detail(error),
        meta: Map.new(error.vars)
      }
    end

    defp detail(error) do
      filter = error.filter
      resource = error.resource

      if is_map(filter) || (Keyword.keyword?(filter) && filter not in [[], %{}]) do
        filter =
          Enum.map_join(filter, ", ", fn {key, value} ->
            try do
              "#{key}: #{to_string(value)}"
            rescue
              _ ->
                "#{key}: #{inspect(value)}"
            end
          end)

        "No #{AshJsonApi.Resource.Info.type(resource)} record found with `#{filter}`"
      else
        if is_nil(error.filter) do
          "No #{AshJsonApi.Resource.Info.type(resource)} record found"
        else
          "No #{AshJsonApi.Resource.Info.type(resource)} record found with `#{inspect(filter)}`"
        end
      end
    end
  end
end
