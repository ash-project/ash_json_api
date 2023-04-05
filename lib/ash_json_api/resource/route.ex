defmodule AshJsonApi.Resource.Route do
  @moduledoc "Represents a route for a resource"
  defstruct [
    :route,
    :action,
    :action_type,
    :default_fields,
    :method,
    :controller,
    :relationship,
    :type,
    :primary?,
    :upsert?,
    :upsert_identity,
    :read_action,
    relationship_arguments: []
  ]

  @type t :: %__MODULE__{}
end
