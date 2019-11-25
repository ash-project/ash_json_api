defmodule AshJsonApi.Error.Forbidden do
  @detail """
  Returned when a user is not allowed to perform an action, or when a user is not present, but must be in order to perform an action.
  """
  @title "Forbidden"
  @status_code 403

  use AshJsonApi.Error
end
