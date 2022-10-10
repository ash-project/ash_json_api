defmodule AshJsonApi.Resource.Route do
  @moduledoc "Represents a route for a resource"
  defstruct [
    :route,
    :action,
    :action_type,
    :method,
    :controller,
    :relationship,
    :type,
    :primary?,
    :upsert?,
    :upsert_identity,
    relationship_arguments: []
  ]

  @type t :: %__MODULE__{}
end
