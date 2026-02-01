# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.InvalidField do
  @moduledoc """
  Returned when a field is requested that does not exist or is invalid
  """

  use Splode.Error,
    class: :invalid,
    fields: [:type, :field, :parameter?, :detail, :source_parameter]

  def message(error) do
    error.detail
  end

  def exception(opts) do
    opts
    |> Keyword.put_new(:detail, "Invalid field for type #{opts[:type]}: #{opts[:field]}")
    |> parameter()
    |> Keyword.drop([:type, :field, :parameter?])
    |> super()
  end

  defp parameter(opts) do
    if opts[:parameter?] do
      Keyword.put_new(opts, :source_parameter, "fields[#{opts[:type]}]")
    else
      Keyword.put_new(opts, :source_parameter, "fields")
    end
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 400,
        code: "invalid_field",
        title: "InvalidField",
        detail: error.detail,
        source_parameter: error.source_parameter,
        meta: %{}
      }
    end
  end
end
