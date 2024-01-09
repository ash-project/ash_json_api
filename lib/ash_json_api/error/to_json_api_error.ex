defprotocol AshJsonApi.ToJsonApiError do
  @moduledoc """
  A protocol for turning an Ash exception into an AshJsonApi.Error

  To use, implement the protocol for a builtin Ash exception type or for your own custom
  Ash exception.

  ## Example

  ```elixir
  defmodule NotAvailable do
    use Ash.Error.Exception

    def_ash_error([:reason], class: :invalid)

    defimpl AshJsonApi.ToJsonApiError do
      def to_json_api_error(error) do
        %AshJsonApi.Error{
          id: Ash.ErrorKind.id(error),
          status_code: 409,
          code: Ash.ErrorKind.code(error),
          title: Ash.ErrorKind.code(error),
          detail: Ash.ErrorKind.message(error)
        }
      end
    end

    defimpl Ash.ErrorKind do
      def id(_), do: Ash.UUID.generate()
      def code(_), do: "not_available"
      def message(error), do: "Not available: \#{error.reason}"
    end
  end
  ```
  """
  @spec to_json_api_error(term) :: AshJsonApi.Error.t() | list(AshJsonApi.Error.t())
  def to_json_api_error(struct)
end
