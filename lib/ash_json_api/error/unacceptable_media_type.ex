defmodule AshJsonApi.Error.UnacceptableMediaType do
  @moduledoc """
  Returned when the client does not provide (via the `Content-Type` header) the correct json API media type: application/vnd.api+json
  """
  @detail @moduledoc
  @title "Unacceptable Media Type"
  @status_code 406

  use AshJsonApi.Error
end
