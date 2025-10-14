# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.UnacceptableMediaType do
  @moduledoc """
  Returned when the client does not provide (via the `Content-Type` header) the correct json API media type: application/vnd.api+json
  """
  use Splode.Error, class: :invalid

  def message(_error) do
    "unacceptable media type"
  end

  defimpl AshJsonApi.ToJsonApiError do
    def to_json_api_error(_error) do
      %AshJsonApi.Error{
        id: Ash.UUID.generate(),
        status_code: 406,
        code: "unacceptable_media_type",
        title: "Unacceptable Media Type",
        meta: %{}
      }
    end
  end
end
