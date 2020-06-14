defmodule AshJsonApi.Resource.Route do
  @moduledoc false
  defstruct [
    :route,
    :action,
    :action_type,
    :method,
    :controller,
    :relationship,
    :type,
    :primary?
  ]

  @type t :: %__MODULE__{}
end
