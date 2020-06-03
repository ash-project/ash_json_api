defmodule AshJsonApi.Error.UnsupportedMediaType do
  @moduledoc """
  Returned when the client does not accept the json API media type: application/vnd.api+json
  """
  @detail @moduledoc
  @title "Unsupported Media Type"
  @status_code 415

  use AshJsonApi.Error
end
