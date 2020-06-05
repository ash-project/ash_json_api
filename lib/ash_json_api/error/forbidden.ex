defmodule AshJsonApi.Error.Forbidden do
  @moduledoc """
  Returned when a actor is not allowed to perform an action, or when a actor is not present, but must be in order to perform an action.
  """
  @detail @moduledoc
  @title "Forbidden"
  @status_code 403

  use AshJsonApi.Error
end
