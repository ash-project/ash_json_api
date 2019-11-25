defmodule AshJsonApi.Error.FrameworkError do
  @detail """
  Returned when an unexpected error in the framework has occured.
  """
  @title "Framework Error"
  @status_code 500

  use AshJsonApi.Error
end
