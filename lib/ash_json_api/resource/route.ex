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
    :name,
    :resource,
    :type,
    :primary?,
    :upsert?,
    :upsert_identity,
    :read_action,
    relationship_arguments: [],
    metadata: nil
  ]

  @type t :: %__MODULE__{}
end
