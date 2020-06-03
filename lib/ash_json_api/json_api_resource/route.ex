defmodule AshJsonApi.JsonApiResource.Route do
  @moduledoc false
  defstruct [
    :route,
    :action,
    :action_type,
    :method,
    :fields,
    :controller,
    :relationship,
    :type,
    :primary?
  ]

  @type t :: %__MODULE__{}

  def new(opts) do
    # TODO: Right now we just skip straight to the action in general.
    %__MODULE__{
      route: opts[:route],
      type: opts[:type],
      action: opts[:action],
      action_type: opts[:action_type],
      primary?: opts[:primary?],
      method: opts[:method],
      controller: opts[:controller],
      relationship: opts[:relationship]
    }
  end
end
