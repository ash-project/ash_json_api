# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defprotocol AshJsonApi.ToJsonApiError do
  @moduledoc """
  A protocol for turning an Ash exception into an AshJsonApi.Error

  To use, implement the protocol for a builtin Ash exception type or for your own custom
  Ash exception.

  ## Example

  ```elixir
  defmodule NotAvailable do
    use Ash.Error.Exception

    use Splode.Error,
      fields: [],
      class: :invalid

    defimpl AshJsonApi.ToJsonApiError do
      def to_json_api_error(error) do
        %AshJsonApi.Error{
          id: Ash.UUID.generate(),
          status_code: 409,
          code: "not_available",
          title: "not_available",
          detail: "Not available"
        }
      end
    end
  end
  ```
  """
  @spec to_json_api_error(term) :: AshJsonApi.Error.t() | list(AshJsonApi.Error.t())
  def to_json_api_error(struct)
end
