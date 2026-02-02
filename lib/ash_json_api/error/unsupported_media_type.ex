# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.UnsupportedMediaType do
  @moduledoc """
  Returned when the client does not accept (via the `Accept` header) the json API media type: application/vnd.api+json
  """
  use Splode.Error, class: :invalid

  def message(_) do
    "unsupported media type"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(_error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 415,
        code: "unsupported_media_type",
        title: "Unsupported Media Type",
        meta: %{}
      }
    end
  end
end
