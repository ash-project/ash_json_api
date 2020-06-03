defmodule AshJsonApi.Error.FrameworkError do
  @moduledoc """
  Returned when an unexpected error in the framework has occured.
  """
  @detail @moduledoc
  @title "Framework Error"
  @status_code 500

  use AshJsonApi.Error
end
