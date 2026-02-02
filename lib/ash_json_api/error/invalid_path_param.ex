# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidPathParam do
  @moduledoc """
  Returned when a required path parameter is missing or invalid
  """

  use Splode.Error,
    class: :invalid,
    fields: [:parameter, :url, :detail]

  def message(error) do
    error.detail
  end

  def exception(opts) do
    parameter = opts[:parameter]
    url = opts[:url]

    detail =
      case {parameter, url} do
        {nil, nil} -> "Required path parameter not present"
        {param, nil} -> "#{param} path parameter not present"
        {nil, url} -> "Required path parameter not present in route: #{url}"
        {param, url} -> "#{param} path parameter not present in route: #{url}"
      end

    opts
    |> Keyword.put_new(:detail, detail)
    |> Keyword.drop([:parameter, :url])
    |> super()
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_path_param",
        title: "InvalidPathParam",
        detail: error.detail,
        meta: %{}
      }
    end
  end
end
