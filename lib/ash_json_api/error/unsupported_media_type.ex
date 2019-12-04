defmodule AshJsonApi.Error.UnsupportedMediaType do
  @detail """
  Returned when the client does not accept the json API media type: application/vnd.api+json
  """
  @title "Unsupported Media Type"
  @status_code 415

  use AshJsonApi.Error
end
